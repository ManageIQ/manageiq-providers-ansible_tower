module ManageIQ
  module Providers
    module AnsibleTower
      class Engine < ::Rails::Engine
        isolate_namespace ManageIQ::Providers::AnsibleTower

        def self.plugin_name
          _('Ansible Tower Provider')
        end
      end
    end
  end
end
