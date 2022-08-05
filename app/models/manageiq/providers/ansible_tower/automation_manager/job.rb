ManageIQ::Providers::Awx::AutomationManager::Job.include(ActsAsStiLeafClass)

require 'ansible_tower_client'
class ManageIQ::Providers::AnsibleTower::AutomationManager::Job <
  ManageIQ::Providers::Awx::AutomationManager::Job
  require_nested :Status

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::AutomationManager"
  belongs_to :job_template, :foreign_key => :orchestration_template_id, :class_name => "ConfigurationScript"
  belongs_to :playbook, :foreign_key => :configuration_script_base_id

  def self.display_name(number = 1)
    n_('Ansible Tower Job', 'Ansible Tower Jobs', number)
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
end
