FactoryBot.define do
  factory :ansible_configuration_workflow,
          :class  => "ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationWorkflow",
          :parent => :configuration_script

  factory :ansible_configuration_script,
          :class  => "ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript",
          :parent => :configuration_script
end
