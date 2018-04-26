module Spec
  module Support
    module TowerDataHelper
      class << self
        def tower_data_initialized?
          File.exist?(file_path)
        end

        def tower_data=(data)
          File.write(file_path, data.to_yaml)
        end

        private

        def file_path
          ManageIQ::Providers::AnsibleTower::Engine.root.join('spec', 'support', 'tower_data.yml')
        end
      end
    end
  end
end
