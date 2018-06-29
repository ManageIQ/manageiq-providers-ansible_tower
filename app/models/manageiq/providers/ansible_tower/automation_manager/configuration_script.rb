class ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript <
  ManageIQ::Providers::ExternalAutomationManager::ConfigurationScript

  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::ConfigurationScript
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::TowerApi

  def self.display_name(number = 1)
    n_('Job Template (Ansible Tower)', 'Job Templates (Ansible Tower)', number)
  end

  def supports_limit?
    true
  end
end
