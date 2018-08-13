class ManageIQ::Providers::AnsibleTower::AutomationManager::WorkflowJob <
  ManageIQ::Providers::ExternalAutomationManager::OrchestrationStack

  require_nested :Status

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::AutomationManager"
  belongs_to :workflow_template, :foreign_key => :orchestration_template_id, :class_name => "ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationWorkflow"

  def self.status_class
    "#{name}::Status".constantize
  end

  #
  # Allowed options are
  #   :extra_vars => Hash
  #
  def self.create_stack(template, options = {})
    new(:name                  => template.name,
        :ext_management_system => template.manager,
        :workflow_template     => template).tap do |stack|
      stack.send(:update_with_provider_object, raw_create_stack(template, options))
    end
  end

  def self.raw_create_stack(template, options = {})
    options = reconcile_extra_vars_keys(template, options)
    template.run(options)
  rescue StandardError => err
    _log.error("Failed to create job from workflow(#{template.name}), error: #{err}")
    raise MiqException::MiqOrchestrationProvisionError, err.to_s, err.backtrace
  end

  class << self
    alias create_job create_stack
    alias raw_create_job raw_create_stack
  end

  # jobs under this workflow job
  alias jobs orchestration_stacks

  def self.display_name(number = 1)
    n_('Ansible Tower Workflow Job', 'Ansible Tower Workflow Jobs', number)
  end

  def raw_status
    ext_management_system.with_provider_connection do |connection|
      raw_job = connection.api.workflow_jobs.find(ems_ref)
      self.class.status_class.new(raw_job.status, nil)
    end
  rescue AnsibleTowerClient::ResourceNotFoundError
    msg = "AnsibleTower Workflow Job #{name} with id(#{id}) does not exist on #{ext_management_system.name}"
    raise MiqException::MiqOrchestrationStackNotExistError, msg
  rescue StandardError => err
    _log.error("AnsibleTower Workflow Job #{name} with id(#{id}) status error: #{err}")
    raise MiqException::MiqOrchestrationStatusError, err.to_s, err.backtrace
  end

  # If extra_vars are passed through automate, all keys are considered as attributes and
  # converted to lower case. Need to convert them back to original definitions in the
  # job template through survey_spec or variables
  def self.reconcile_extra_vars_keys(template, options)
    extra_vars = options[:extra_vars]
    return options if extra_vars.blank?

    defined_extra_vars = Array(Hash(template.survey_spec)['spec']).collect { |s| s['variable'] }
    defined_extra_vars |= Hash(template.variables).keys
    extra_vars_lookup = defined_extra_vars.collect { |key| [key.downcase, key] }.to_h

    extra_vars = extra_vars.transform_keys do |key|
      extra_vars_lookup[key.downcase] || key
    end

    options.merge(:extra_vars => extra_vars)
  end
  private_class_method :reconcile_extra_vars_keys

  def refresh_ems
    ext_management_system.with_provider_connection do |connection|
      update_with_provider_object(connection.api.workflow_jobs.find(ems_ref))
    end
  rescue AnsibleTowerClient::ResourceNotFoundError
    msg = "AnsibleTower Workflow Job #{name} with id(#{id}) does not exist on #{ext_management_system.name}"
    raise MiqException::MiqOrchestrationStackNotExistError, msg
  rescue StandardError => err
    _log.error("Refreshing Workflow job(#{name}, ems_ref=#{ems_ref}), error: #{err}")
    raise MiqException::MiqOrchestrationUpdateError, err.to_s, err.backtrace
  end

  def update_with_provider_object(raw_workflow_job)
    update_attributes(
      :ems_ref     => raw_workflow_job.id,
      :status      => raw_workflow_job.status,
      :start_time  => raw_workflow_job.started,
      :finish_time => raw_workflow_job.finished
    )

    update_parameters(raw_workflow_job) if parameters.empty?

    raw_workflow_job.workflow_job_nodes.each do |node|
      update_child_job(node.job) if node.job
    end
  end
  private :update_with_provider_object

  def update_child_job(raw_job)
    job = jobs.find_by(:ems_ref => raw_job.id)
    unless job
      job_template = ext_management_system.configuration_scripts.find_by(:manager_ref => raw_job.job_template_id)
      job = ManageIQ::Providers::AnsibleTower::AutomationManager::Job.create(
        :name                  => job_template.name,
        :ext_management_system => job_template.manager,
        :job_template          => job_template,
        :ems_ref               => raw_job.id,
        :parent                => self
      )
    end
    job.refresh_ems
  end
  private :update_child_job

  def update_parameters(raw_job)
    self.parameters = raw_job.extra_vars_hash.collect do |para_key, para_val|
      OrchestrationStackParameter.new(:name => para_key, :value => para_val, :ems_ref => "#{raw_job.id}_#{para_key}")
    end
  end
  private :update_parameters

  def retire_now(requester = nil)
    update_attributes(:retirement_requester => requester)
    finish_retirement

    Array(jobs).each { |job| job.retire_now(requester) }
  end
end
