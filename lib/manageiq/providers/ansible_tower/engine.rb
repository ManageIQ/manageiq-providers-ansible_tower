module ManageIQ
  module Providers
    module AnsibleTower
      class Engine < ::Rails::Engine
        isolate_namespace ManageIQ::Providers::AnsibleTower

        config.autoload_paths << root.join('lib').to_s

        def self.vmdb_plugin?
          true
        end

        def self.plugin_name
          _('Ansible Tower Provider')
        end
      end
    end
  end
end
