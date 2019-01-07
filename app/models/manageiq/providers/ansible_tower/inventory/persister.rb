class ManageIQ::Providers::AnsibleTower::Inventory::Persister < ManageIQ::Providers::Inventory::Persister
  require_nested :AutomationManager
  require_nested :ConfigurationScriptSource
end
