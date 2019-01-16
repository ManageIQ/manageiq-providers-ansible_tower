module ManageIQ::Providers::AnsibleTower::Inventory::Persister::Definitions::AutomationCollections
  extend ActiveSupport::Concern

  def initialize_automation_inventory_collections
    %i(credentials
       configuration_script_sources
       configured_systems).each do |name|

      add_collection(automation, name)
    end

    add_configuration_scripts

    add_configuration_script_payloads

    add_inventory_root_groups

    add_vms
  end

  # ------ IC provider specific definitions -------------------------
  def add_inventory_root_groups
    add_collection(automation, :inventory_root_groups) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::AutomationManager::InventoryRootGroup)
    end
  end

  def add_configuration_scripts
    add_collection(automation, :configuration_scripts) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::AutomationManager::ConfigurationScript)
    end
  end

  def add_configuration_script_payloads(extra_properties = {})
    add_collection(automation, :configuration_script_payloads, extra_properties) do |builder|
      builder.add_properties(
        :model_class => ManageIQ::Providers::Inflector.provider_module(self.class)::AutomationManager::Playbook
      )
    end
  end

  def add_vms
    add_collection(automation, :vms) do |builder|
      builder.add_properties(
        :parent   => nil,
        :arel     => Vm,
        :strategy => :local_db_find_references
      )
    end
  end
end
