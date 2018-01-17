class ManageIQ::Providers::AnsibleTower::AutomationManager::Satellite6Credential < ManageIQ::Providers::AnsibleTower::AutomationManager::CloudCredential
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::Satellite6Credential

  def self.display_name(number = 1)
    n_('Credential (Satellite)', 'Credentials (Satellite)', number)
  end
end
