class ManageIQ::Providers::AnsibleTower::Inventory < ManageIQ::Providers::Awx::Inventory
  def self.parser_classes_for(ems, target)
    case target
    when InventoryRefresh::TargetCollection
      [ManageIQ::Providers::AnsibleTower::Inventory::Parser::AutomationManager]
    else
      super
    end
  end
end
