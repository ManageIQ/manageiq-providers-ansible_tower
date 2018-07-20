module ManageIQ::Providers::AnsibleTower::Inventory::Persister::Definitions::Collections
  extend ActiveSupport::Concern

  # ------ IC provider specific definitions -------------------------
  def add_inventory_root_groups
    add_collection(automation, :inventory_root_groups) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::AutomationManager::InventoryRootGroup)
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
