class ManageIQ::Providers::AnsibleTower::Inventory < ManageIQ::Providers::Awx::Inventory
  require_nested :Collector
  require_nested :Parser
  require_nested :Persister

  def self.parser_classes_for(ems, target)
    case target
    when InventoryRefresh::TargetCollection
      [ManageIQ::Providers::AnsibleTower::Inventory::Parser::AutomationManager]
    else
      super
    end
  end
end
