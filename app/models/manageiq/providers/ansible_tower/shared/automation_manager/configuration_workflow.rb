module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::ConfigurationWorkflow
  extend ActiveSupport::Concern

  include ProviderObjectMixin

  module ClassMethods
    def provider_collection(manager)
      manager.with_provider_connection do |connection|
        connection.api.workflow_job_templates
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
    {:extra_vars => variables.merge(external || {}).to_json}
  end

  def provider_object(connection = nil)
    (connection || connection_source.connect).api.workflow_job_templates.find(manager_ref)
  end

  FRIENDLY_NAME = 'Ansible Tower Workflow Job Template'.freeze
end
