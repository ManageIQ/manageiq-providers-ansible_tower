module Spec
  module Support
    module TowerDataHelper
      class << self
        def tower_data
          YAML.load_file(file_path)
        end

        private

        def file_path
          ManageIQ::Providers::AnsibleTower::Engine.root.join('spec', 'support', 'tower_data.yml')
        end
      end
    end
  end
end
