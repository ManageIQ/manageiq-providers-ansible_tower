class ManageIQ::Providers::AnsibleTower::AutomationManager::NetworkCredential < ManageIQ::Providers::AnsibleTower::AutomationManager::Credential
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::NetworkCredential

  def self.display_name(number = 1)
    n_('Credential (Network)', 'Credentials (Network)', number)
  end
end
