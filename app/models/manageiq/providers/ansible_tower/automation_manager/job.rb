class ManageIQ::Providers::AnsibleTower::AutomationManager::Job <
  ManageIQ::Providers::AutomationManager::OrchestrationStack
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::Job

  require_nested :Status

  def self.display_name(number = 1)
    n_('Ansible Tower Job', 'Ansible Tower Jobs', number)
  end
end
