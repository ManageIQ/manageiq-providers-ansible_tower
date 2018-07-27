if ENV['CI']
  require 'simplecov'
  SimpleCov.start
end

require 'vcr'
require 'cgi'

# Uncomment in case you use vcr cassettes
VCR.configure do |config|
  config.ignore_hosts 'codeclimate.com' if ENV['CI']
  config.cassette_library_dir = File.join(ManageIQ::Providers::AnsibleTower::Engine.root, 'spec/vcr_cassettes')

  # Set your config/secrets.yml file
  secrets = Rails.application.secrets

  # Looks for provider subkeys you set in secrets.yml. Replace the values of
  # those keys (both escaped or unescaped) with some placeholder text.
  secrets.each_key do |provider|
    next if %i(secret_key_base secret_token).include?(provider) # Defaults
    cred_hash = secrets.public_send(provider)
    cred_hash.each do |key, value|
      config.filter_sensitive_data("#{provider.upcase}_#{key.upcase}") { CGI.escape(value) }
      config.filter_sensitive_data("#{provider.upcase}_#{key.upcase}") { value }
    end
  end
end

Dir[Rails.root.join("spec/shared/**/*.rb")].each { |f| require f }
Dir[ManageIQ::Providers::AnsibleTower::Engine.root.join("spec/support/**/*.rb")].each { |f| require f }
