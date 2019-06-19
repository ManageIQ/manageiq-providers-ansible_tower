module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager
  extend ActiveSupport::Concern

  include ProcessTasksMixin
  delegate :authentications,
           :authentication_check,
           :authentication_status,
           :authentication_status_ok?,
           :connect,
           :verify_credentials,
           :with_provider_connection,
           :to => :provider

  def self.included(klass)
    klass.after_save :change_maintenance_for_provider, :if => proc { |ems| ems.saved_change_to_enabled? }
  end

  module ClassMethods
    private

    def connection_source(options = {})
      options[:connection_source] || self
    end
  end

  def image_name
    "ansible"
  end

  def change_maintenance_for_provider
    if provider.present? && saved_change_to_zone_id?
      provider.zone_id = zone_id
      provider.save
    end
  end
end
