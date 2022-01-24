module ManageIQ::Providers::AnsibleTower::Inventory::Persister::Definitions::AutomationCollections
  extend ActiveSupport::Concern

  def initialize_automation_inventory_collections
    %i[
      authentication_configuration_script_bases
      credentials
      configuration_scripts
      configuration_script_sources
      configured_systems
      cross_link_vms
    ].each do |name|
      add_collection(automation, name)
    end

    add_configuration_script_payloads

    add_inventory_root_groups
  end

  # ------ IC provider specific definitions -------------------------
  def add_inventory_root_groups
    add_collection(automation, :inventory_root_groups) do |builder|
      builder.add_properties(:model_class => ManageIQ::Providers::Inflector.provider_module(self.class)::AutomationManager::Inventory)
    end
  end

  def add_configuration_script_payloads(extra_properties = {})
    add_collection(automation, :configuration_script_payloads, extra_properties) do |builder|
      builder.add_properties(
        :model_class => ManageIQ::Providers::Inflector.provider_module(self.class)::AutomationManager::Playbook
      )
    end
  end
end
