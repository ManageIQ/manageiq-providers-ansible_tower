class ManageIQ::Providers::AnsibleTower::Inventory::Persister::ConfigurationScriptSource < ManageIQ::Providers::AnsibleTower::Inventory::Persister
  include ManageIQ::Providers::AnsibleTower::Inventory::Persister::Definitions::Collections

  def initialize_inventory_collections
    add_collection(automation, :credentials, :complete => false)

    add_collection(automation, :configuration_script_sources, :complete => false)

    add_configuration_script_payloads(:parent => target)
  end
end
