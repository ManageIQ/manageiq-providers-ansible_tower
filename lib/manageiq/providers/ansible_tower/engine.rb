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

        def self.init_loggers
          $ansible_tower_log ||= Vmdb::Loggers.create_logger("ansible_tower.log")
        end

        def self.apply_logger_config(config)
          Vmdb::Loggers.apply_config_value(config, $ansible_tower_log, :level_ansible_tower)
        end
      end
    end
  end
end
