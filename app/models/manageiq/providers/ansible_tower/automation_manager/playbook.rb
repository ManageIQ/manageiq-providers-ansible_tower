class ManageIQ::Providers::AnsibleTower::AutomationManager::Playbook <
  ManageIQ::Providers::ExternalAutomationManager::ConfigurationScriptPayload

  has_many :jobs, :class_name => 'OrchestrationStack', :foreign_key => :configuration_script_base_id

  def self.display_name(number = 1)
    n_('Playbook (Ansible Tower)', 'Playbooks (Ansible Tower)', number)
  end
end
