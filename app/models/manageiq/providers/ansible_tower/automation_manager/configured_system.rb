ManageIQ::Providers::Awx::AutomationManager::ConfiguredSystem.include(ActsAsStiLeafClass)

class ManageIQ::Providers::AnsibleTower::AutomationManager::ConfiguredSystem <
  ManageIQ::Providers::Awx::AutomationManager::ConfiguredSystem

  def self.display_name(number = 1)
    n_('Configured System (Ansible Tower)', 'Configured Systems (Ansible Tower)', number)
  end
end
