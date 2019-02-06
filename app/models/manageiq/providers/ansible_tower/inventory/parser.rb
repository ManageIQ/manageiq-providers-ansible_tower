class ManageIQ::Providers::AnsibleTower::Inventory::Parser < ManageIQ::Providers::Inventory::Parser
  require_nested :AutomationManager
  require_nested :ConfigurationScriptSource
end
