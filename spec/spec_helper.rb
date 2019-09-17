if ENV['CI']
  require 'simplecov'
  SimpleCov.start
end

# Uncomment in case you use vcr cassettes
VCR.configure do |config|
  config.ignore_hosts 'codeclimate.com' if ENV['CI']
  config.cassette_library_dir = File.join(ManageIQ::Providers::AnsibleTower::Engine.root, 'spec/vcr_cassettes')
end

shared_context "uses tower_data.yml" do
  let(:tower_data) { YAML.load_file(ManageIQ::Providers::AnsibleTower::Engine.root.join("spec/support/tower_data.yml")) }
end

Dir[ManageIQ::Providers::AnsibleTower::Engine.root.join("spec/support/**/*.rb")].each { |f| require f }
