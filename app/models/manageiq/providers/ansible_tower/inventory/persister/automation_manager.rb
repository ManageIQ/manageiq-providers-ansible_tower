class ManageIQ::Providers::AnsibleTower::Inventory::Persister::AutomationManager < ManageIQ::Providers::AnsibleTower::Inventory::Persister
  include ManageIQ::Providers::AnsibleTower::Inventory::Persister::Definitions::Collections

  def initialize_inventory_collections
    %i(credentials
       configuration_scripts
       configuration_script_sources
       configuration_workflows
       configured_systems
       inventory_root_groups).each do |name|

      add_collection(automation, name)
    end

    add_configuration_script_payloads

    add_vms
  end
end
