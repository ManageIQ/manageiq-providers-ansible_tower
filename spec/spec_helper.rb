if ENV['CI']
  require 'simplecov'
  SimpleCov.start
end

# Uncomment in case you use vcr cassettes
VCR.configure do |config|
  config.ignore_hosts 'codeclimate.com' if ENV['CI']
  config.cassette_library_dir = File.join(ManageIQ::Providers::AnsibleTower::Engine.root, 'spec/vcr_cassettes')
end

Dir[File.join(ManageIQ::Providers::AnsibleTower::Engine.root, 'spec/support/**/*.rb')].each { |f| require f }
