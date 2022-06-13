ManageIQ::Providers::Awx::AutomationManager::WorkflowJob.include(ActsAsStiLeafClass)

class ManageIQ::Providers::AnsibleTower::AutomationManager::WorkflowJob <
  ManageIQ::Providers::Awx::AutomationManager::WorkflowJob

  require_nested :Status

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::AutomationManager"
  belongs_to :workflow_template, :foreign_key => :orchestration_template_id, :class_name => "ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationWorkflow"

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

  def update_child_workflow_job(raw_workflow_job)
    job = jobs.find_by(:ems_ref => raw_workflow_job.id)
    unless job
      workflow_template = ext_management_system.configuration_scripts.find_by(:manager_ref => raw_workflow_job.workflow_job_template_id)
      job = ManageIQ::Providers::AnsibleTower::AutomationManager::WorkflowJob.create(
        :name                  => workflow_template.name,
        :ext_management_system => workflow_template.manager,
        :workflow_template     => workflow_template,
        :ems_ref               => raw_workflow_job.id,
        :parent                => self
      )
    end
    job.refresh_ems
  end
  private :update_child_workflow_job
end
