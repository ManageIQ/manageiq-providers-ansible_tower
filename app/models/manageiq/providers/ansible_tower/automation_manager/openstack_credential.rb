class ManageIQ::Providers::AnsibleTower::AutomationManager::OpenstackCredential < ManageIQ::Providers::AnsibleTower::AutomationManager::CloudCredential
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::OpenstackCredential

  def self.display_name(number = 1)
    n_('Credential (OpenStack)', 'Credentials (OpenStack)', number)
  end
end
