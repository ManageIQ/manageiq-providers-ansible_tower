class ManageIQ::Providers::AnsibleTower::AutomationManager::ScmCredential < ManageIQ::Providers::AnsibleTower::AutomationManager::Credential
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::ScmCredential

  def self.display_name(number = 1)
    n_('Credential (SCM)', 'Credentials (SCM)', number)
  end
end
