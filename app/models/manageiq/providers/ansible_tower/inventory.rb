class ManageIQ::Providers::AnsibleTower::Inventory < ManageIQ::Providers::Inventory
  require_nested :Collector
  require_nested :Parser
  require_nested :Persister

  def self.default_manager_name
    "AutomationManager"
  end

  # TODO (mslemr) change needed if used by embedded ansible
  def self.parser_classes_for(ems, target)
    case target
    when InventoryRefresh::TargetCollection
      # [ManageIQ::Providers::AnsibleTower::Inventory::Parser::AutomationManager,
      #  ManageIQ::Providers::AnsibleTower::Inventory::Parser::ConfigurationScriptSource]
      [ManageIQ::Providers::AnsibleTower::Inventory::Parser::AutomationManager]
    else
      super
    end
  end
end
