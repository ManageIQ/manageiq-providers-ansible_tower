class ManageIQ::Providers::AnsibleTower::AutomationManager::TemplateRunner < ::Job
  DEFAULT_EXECUTION_TTL = 10 # minutes

  def self.create_job(options)
    super(options.with_indifferent_access)
  end

  def minimize_indirect
    @minimize_indirect = true if @minimize_indirect.nil?
    @minimize_indirect
  end

  def current_job_timeout(_timeout_adjustment = 1)
    @execution_ttl ||=
      (options[:execution_ttl].present? ? options[:execution_ttl].try(:to_i) : DEFAULT_EXECUTION_TTL) * 60
  end

  def start(priority: nil)
    time = Time.zone.now
    update(:started_on => time)
    miq_task.update(:started_on => time)
    my_signal(false, :launch_ansible_tower_job, :priority => priority)
  end

  def launch_ansible_tower_job
    set_status('launching tower job')

    launch_options = options.slice(:extra_vars, :limit)
    tower_job = job_class.create_job(job_template, launch_options)
    options[:tower_job_id] = tower_job.id
    self.name = "#{name}, Job ID: #{tower_job.id}"
    miq_task.update(:name => name)
    save!

    my_signal(false, :poll_ansible_tower_job_status, 10)
  rescue StandardError => err
    _log.log_backtrace(err)
    my_signal(minimize_indirect, :post_ansible_run, err.message, 'error')
  end

  def poll_ansible_tower_job_status(interval)
    set_status('waiting for tower job to complete')

    tower_job_status = ansible_job.raw_status
    if tower_job_status.completed?
      ansible_job.refresh_ems
      log_stdout(tower_job_status)
      if tower_job_status.succeeded?
        my_signal(minimize_indirect, :post_ansible_run, job_finish_message, 'ok')
      else
        my_signal(minimize_indirect, :post_ansible_run, 'Ansible engine returned an error for the job', 'error')
      end
    else
      interval = 60 if interval > 60
      my_signal(false, :poll_ansible_tower_job_status, interval, :deliver_on => Time.now.utc + interval)
    end
  rescue StandardError => err
    _log.log_backtrace(err)
    my_signal(minimize_indirect, :post_ansible_run, err.message, 'error')
  end

  def post_ansible_run(message, status)
    my_signal(true, :finish, message, status)
  end

  def ansible_job
    job_class.find_by(:id => options[:tower_job_id])
  end

  def set_status(message, status = "ok")
    _log.info(message)
    super
  end

  def job_template
    @template ||= ManageIQ::Providers::ExternalAutomationManager::ConfigurationScript.find(options[:ansible_template_id])
  end

  def wait_on_ansible_job
    while ansible_job.blank?
      _log.info("Waiting for the schedule of ansible job from template #{job_template.name}")
      sleep 2
      # Code running with Rails QueryCache enabled,
      # need to disable caching for the reload to see updates.
      self.class.uncached { reload }
    end
    ansible_job
  end

  alias initializing dispatch_start
  alias finish       process_finished
  alias abort_job    process_abort
  alias cancel       process_cancel
  alias error        process_error

  private

  attr_writer :minimize_indirect

  def load_transitions
    self.state ||= 'initialize'

    {
      :initializing                  => {'initialize'       => 'waiting_to_start'},
      :start                         => {'waiting_to_start' => 'running'},
      :launch_ansible_tower_job      => {'running'          => 'ansible_job'},
      :poll_ansible_tower_job_status => {'ansible_job'      => 'ansible_job'},
      :post_ansible_run              => {'ansible_job'      => 'ansible_done'},
      :finish                        => {'*'                => 'finished'},
      :abort_job                     => {'*'                => 'aborting'},
      :cancel                        => {'*'                => 'canceling'},
      :error                         => {'*'                => '*'}
    }
  end

  def my_signal(no_queue, action, *args, deliver_on: nil, priority: nil)
    if no_queue
      signal(action, *args)
    else
      queue_signal(action, *args, :deliver_on => deliver_on, :priority => priority)
    end
  end

  def queue_signal(*args, deliver_on: nil, priority: nil)
    priority ||= options[:priority] || MiqQueue::NORMAL_PRIORITY

    MiqQueue.put(
      :class_name  => self.class.name,
      :method_name => "signal",
      :instance_id => id,
      :priority    => priority,
      :role        => 'ems_operations',
      :zone        => zone || job_template.manager.my_zone,
      :args        => args,
      :deliver_on  => deliver_on
    )
  end

  def log_stdout(tower_job_status)
    return unless ansible_job.respond_to?(:raw_stdout)
    return unless %(on_error always).include?(options[:log_output])
    return if options[:log_output] == 'on_error' && tower_job_status.succeeded?
    _log.info("Stdout from ansible template #{job_template.name}: #{ansible_job.raw_stdout('txt_download')}")
  rescue StandardError => err
    _log.error("Failed to get stdout from ansible template #{job_template.name}")
    _log.log_backtrace(err)
  end

  def job_class
    "#{job_template.class.module_parent.name}::#{job_template.class.stack_type}".constantize
  end

  def job_finish_message
    "Template [#{job_template.name}] ran successfully"
  end
end
