if ENV['CI']
  require 'simplecov'
  SimpleCov.start
end

Dir[Rails.root.join("spec/shared/**/*.rb")].each { |f| require f }
Dir[File.join(__dir__, "support/**/*.rb")].each { |f| require f }

require "manageiq/providers/ansible_tower"

VCR.configure do |config|
  config.ignore_hosts 'codeclimate.com' if ENV['CI']
  config.cassette_library_dir = File.join(ManageIQ::Providers::AnsibleTower::Engine.root, 'spec/vcr_cassettes')
  Rails.application.secrets.ansible_tower.keys do |secret|
    config.define_cassette_placeholder(Rails.application.secrets.ansible_tower_defaults[secret]) do
      Rails.application.secrets.ansible_tower[secret]
    end
  end
end
