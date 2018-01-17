class ManageIQ::Providers::AnsibleTower::AutomationManager::GoogleCredential < ManageIQ::Providers::AnsibleTower::AutomationManager::CloudCredential
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::GoogleCredential

  def self.display_name(number = 1)
    n_('Credential (Google)', 'Credentials (Google)', number)
  end
end
