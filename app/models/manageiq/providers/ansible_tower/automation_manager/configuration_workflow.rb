class ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationWorkflow < ManageIQ::Providers::ExternalAutomationManager::ConfigurationScript
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::ConfigurationWorkflow

  def self.stack_type
    "WorkflowJob"
  end

  def supports_limit?
    false
  end

  def self.display_name(number = 1)
    n_('Workflow Template (Ansible Tower)', 'Workflow Templates (Ansible Tower)', number)
  end
end
