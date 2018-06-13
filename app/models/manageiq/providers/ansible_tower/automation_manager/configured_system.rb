class ManageIQ::Providers::AnsibleTower::AutomationManager::ConfiguredSystem <
  ManageIQ::Providers::ExternalAutomationManager::ConfiguredSystem

  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::ConfiguredSystem
  include ProviderObjectMixin

  def self.display_name(number = 1)
    n_('Configured System (Ansible Tower)', 'Configured Systems (Ansible Tower)', number)
  end
end
