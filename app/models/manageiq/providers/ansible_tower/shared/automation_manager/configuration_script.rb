module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::ConfigurationScript
  extend ActiveSupport::Concern

  include ProviderObjectMixin

  module ClassMethods
    def provider_collection(manager)
      manager.with_provider_connection do |connection|
        connection.api.job_templates
      end
    end
  end

  def run(vars = {})
    options = vars.merge(merge_extra_vars(vars[:extra_vars]))

    with_provider_object do |jt|
      jt.launch(options)
    end
  end

  def merge_extra_vars(external)
    extra_vars = variables.merge(external || {}).each_with_object({}) do |(k, v), hash|
      match_data = v.kind_of?(String) && /password::/.match(v)
      hash[k] = match_data ? MiqPassword.decrypt(v.gsub(/password::/, '')) : v
    end
    {:extra_vars => extra_vars.to_json}
  end

  def provider_object(connection = nil)
    (connection || connection_source.connect).api.job_templates.find(manager_ref)
  end

  FRIENDLY_NAME = 'Ansible Tower Job Template'.freeze
end
