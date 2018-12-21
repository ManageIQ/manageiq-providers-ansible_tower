class ManageIQ::Providers::AnsibleTower::Inventory::Persister < ManageIQ::Providers::Inventory::Persister
  require_nested :AutomationManager
  require_nested :ConfigurationScriptSource

  # Shared properties for inventory collections
  def shared_options
    {
      :parent => manager.presence
    }
  end
end
