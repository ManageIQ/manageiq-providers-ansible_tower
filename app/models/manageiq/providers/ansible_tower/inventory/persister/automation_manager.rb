class ManageIQ::Providers::AnsibleTower::Inventory::Persister::AutomationManager < ManageIQ::Providers::AnsibleTower::Inventory::Persister
  include ManageIQ::Providers::AnsibleTower::Inventory::Persister::Definitions::AutomationCollections

  def initialize_inventory_collections
    initialize_automation_inventory_collections
  end
end
