require 'ansible_tower_client'
class ManageIQ::Providers::AnsibleTower::AutomationManager::Job <
  ManageIQ::Providers::ExternalAutomationManager::OrchestrationStack
  require_nested :Status

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::AutomationManager"
  belongs_to :job_template, :foreign_key => :orchestration_template_id, :class_name => "ConfigurationScript"
  belongs_to :playbook, :foreign_key => :configuration_script_base_id

  virtual_has_many :job_plays

  def self.display_name(number = 1)
    n_('Ansible Tower Job', 'Ansible Tower Jobs', number)
  end

  class << self
    #
    # Allowed options are
    #   :limit      => String
    #   :extra_vars => Hash
    #
    def create_stack(template, options = {})
      template_ref = template.new_record? ? nil : template
      new(:name                  => template.name,
          :ext_management_system => template.manager,
          :job_template          => template_ref).tap do |stack|
        stack.send(:update_with_provider_object, raw_create_stack(template, options))
      end
    end

    def raw_create_stack(template, options = {})
      options = reconcile_extra_vars_keys(template, options)
      template.run(options)
    rescue => err
      _log.error("Failed to create job from template(#{template.name}), error: #{err}")
      raise MiqException::MiqOrchestrationProvisionError, err.to_s, err.backtrace
    end

    def db_name
      'ConfigurationJob'
    end

    def status_class
      "#{name}::Status".constantize
    end

    alias create_job create_stack
    alias raw_create_job raw_create_stack

    private

    # If extra_vars are passed through automate, all keys are considered as attributes and
    # converted to lower case. Need to convert them back to original definitions in the
    # job template through survey_spec or variables
    def reconcile_extra_vars_keys(template, options)
      extra_vars = options[:extra_vars]
      return options if extra_vars.blank?

      defined_extra_vars = (Hash(template.survey_spec)['spec'] || {}).collect { |s| s['variable'] }
      defined_extra_vars |= Hash(template.variables).keys
      extra_vars_lookup = defined_extra_vars.collect { |key| [key.downcase, key] }.to_h

      extra_vars = extra_vars.transform_keys do |key|
        extra_vars_lookup[key.downcase] || key
      end

      options.merge(:extra_vars => extra_vars)
    end
  end

  def job_plays
    resources.where(:resource_category => 'job_play').order(:start_time)
  end

  def refresh_ems
    ext_management_system.with_provider_connection do |connection|
      update_with_provider_object(connection.api.jobs.find(ems_ref))
    end
  rescue AnsibleTowerClient::ResourceNotFoundError
    msg = "AnsibleTower Job #{name} with id(#{id}) does not exist on #{ext_management_system.name}"
    raise MiqException::MiqOrchestrationStackNotExistError, msg
  rescue => err
    _log.error "Refreshing job(#{name}, ems_ref=#{ems_ref}), error: #{err}"
    raise MiqException::MiqOrchestrationUpdateError, err.to_s, err.backtrace
  end

  def update_with_provider_object(raw_job)
    update(
      :ems_ref     => raw_job.id,
      :status      => raw_job.status,
      :start_time  => raw_job.started,
      :finish_time => raw_job.finished,
      :verbosity   => raw_job.verbosity
    )

    update_parameters(raw_job) if parameters.empty?

    update_credentials(raw_job) if authentications.empty?

    update_plays(raw_job)
  end
  private :update_with_provider_object

  def update_parameters(raw_job)
    self.parameters = raw_job.extra_vars_hash.collect do |para_key, para_val|
      OrchestrationStackParameter.new(:name => para_key, :value => para_val, :ems_ref => "#{raw_job.id}_#{para_key}")
    end
  end
  private :update_parameters

  def update_credentials(raw_job)
    credential_types = %w(credential_id vault_credential_id cloud_credential_id network_credential_id)
    credential_refs = credential_types.collect { |attr| raw_job.try(attr) }.delete_blanks
    self.authentications = ext_management_system.credentials.where(:manager_ref => credential_refs)
  end
  private :update_credentials

  def update_plays(raw_job)
    last_play_hash = nil
    plays = raw_job.job_events(:event => 'playbook_on_play_start').collect do |play|
      {
        :name              => play.play,
        :resource_status   => play.failed ? 'failed' : 'successful',
        :start_time        => play.created,
        :ems_ref           => play.id,
        :resource_category => 'job_play'
      }.tap do |h|
        last_play_hash[:finish_time] = play.created if last_play_hash
        last_play_hash = h
      end
    end
    last_play_hash[:finish_time] = raw_job.finished if last_play_hash

    old_resources = resources
    self.resources = plays.collect do |play_hash|
      old_resource = old_resources.find { |o| o.ems_ref == play_hash[:ems_ref].to_s }
      if old_resource
        old_resource.update(play_hash)
        old_resource
      else
        OrchestrationStackResource.new(play_hash)
      end
    end
  end
  private :update_plays

  def raw_status
    ext_management_system.with_provider_connection do |connection|
      raw_job = connection.api.jobs.find(ems_ref)
      self.class.status_class.new(raw_job.status, nil)
    end
  rescue AnsibleTowerClient::ResourceNotFoundError
    msg = "AnsibleTower Job #{name} with id(#{id}) does not exist on #{ext_management_system.name}"
    raise MiqException::MiqOrchestrationStackNotExistError, msg
  rescue => err
    _log.error "AnsibleTower Job #{name} with id(#{id}) status error: #{err}"
    raise MiqException::MiqOrchestrationStatusError, err.to_s, err.backtrace
  end

  def raw_stdout(format = 'txt')
    ext_management_system.with_provider_connection do |connection|
      connection.api.jobs.find(ems_ref).stdout(format)
    end
  rescue AnsibleTowerClient::ResourceNotFoundError
    msg = "AnsibleTower Job #{name} with id(#{id}) or its stdout does not exist on #{ext_management_system.name}"
    raise MiqException::MiqOrchestrationStackNotExistError, msg
  rescue => err
    _log.error "Reading AnsibleTower Job #{name} with id(#{id}) stdout failed with error: #{err}"
    raise MiqException::MiqOrchestrationStatusError, err.to_s, err.backtrace
  end

  def raw_artifacts
    ext_management_system.with_provider_connection do |connection|
      connection.api.jobs.find(ems_ref).artifacts
    end
  rescue AnsibleTowerClient::ResourceNotFoundError
    msg = "AnsibleTower Job #{name} with id(#{id}) or its artifacts does not exist on #{ext_management_system.name}"
    raise MiqException::MiqOrchestrationStackNotExistError, msg
  rescue => err
    _log.error("Reading AnsibleTower Job #{name} with id(#{id}) artifacts failed with error: #{err}")
    raise MiqException::MiqOrchestrationStatusError, err.to_s, err.backtrace
  end

  # Intend to be called by UI to display stdout. The stdout is stored in MiqTask#task_results or #message if error
  # Since the task_results may contain a large block of data, it is desired to remove the task upon receiving the data
  def raw_stdout_via_worker(userid, format = 'txt', role = nil)
    options = {:userid => userid || 'system', :action => 'ansible_stdout'}
    queue_options = {
      :class_name  => self.class,
      :method_name => 'raw_stdout',
      :instance_id => id,
      :args        => [format],
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => role
    }

    MiqTask.generic_action_with_callback(options, queue_options)
  end

  def retire_now(requester = nil)
    update(:retirement_requester => requester)
    finish_retirement
  end
end
