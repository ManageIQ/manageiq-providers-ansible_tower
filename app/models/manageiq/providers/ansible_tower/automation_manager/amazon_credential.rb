class ManageIQ::Providers::AnsibleTower::AutomationManager::AmazonCredential < ManageIQ::Providers::AnsibleTower::AutomationManager::CloudCredential
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::AmazonCredential

  def self.display_name(number = 1)
    n_('Credential (Amazon)', 'Credentials (Amazon)', number)
  end
end
