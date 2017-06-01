module ManageIQ
  module Providers
    module AnsibleTower
      class Engine < ::Rails::Engine
        isolate_namespace ManageIQ::Providers::AnsibleTower
      end
    end
  end
end
