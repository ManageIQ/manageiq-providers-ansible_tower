class ManageIQ::Providers::AnsibleTower::AutomationManager::MachineCredential < ManageIQ::Providers::AnsibleTower::AutomationManager::Credential
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::MachineCredential

  def self.display_name(number = 1)
    n_('Credential (Machine)', 'Credentials (Machine)', number)
  end
end
