class ManageIQ::Providers::AnsibleTower::AutomationManager::VmwareCredential < ManageIQ::Providers::AnsibleTower::AutomationManager::CloudCredential
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::VmwareCredential

  def self.display_name(number = 1)
    n_('Credential (VMware)', 'Credentials (VMware)', number)
  end
end
