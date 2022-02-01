class ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript <
  ManageIQ::Providers::ExternalAutomationManager::ConfigurationScript
  include ProviderObjectMixin
  include ManageIQ::Providers::AnsibleTower::AutomationManager::TowerApi

  supports :create

  def run_with_miq_job(options, userid = nil)
    options[:name] = "Job Template: #{name}"
    options[:ansible_template_id] = id
    options[:userid] = userid || 'system'
    miq_job = ManageIQ::Providers::AnsibleTower::AutomationManager::TemplateRunner.create_job(options)
    miq_job.signal(:start)
    miq_job.miq_task.id
  end

  def self.display_name(number = 1)
    n_('Job Template (Ansible Tower)', 'Job Templates (Ansible Tower)', number)
  end

  def self.stack_type
    "Job"
  end

  def supports_limit?
    true
  end

  def self.provider_collection(manager)
    manager.with_provider_connection do |connection|
      connection.api.job_templates
    end
  end

  def run(vars = {})
    options = vars.merge(merge_extra_vars(vars[:extra_vars]))

    with_provider_object do |jt|
      jt.launch(options)
    end
  end

  def merge_extra_vars(external)
    extra_vars = variables.to_h.merge(external.to_h).each_with_object({}) do |(k, v), hash|
      match_data = v.kind_of?(String) && /password::/.match(v)
      hash[k] = match_data ? ManageIQ::Password.decrypt(v.gsub(/password::/, '')) : v
    end
    {:extra_vars => extra_vars.to_json}
  end

  def provider_object(connection = nil)
    (connection || connection_source.connect).api.job_templates.find(manager_ref)
  end

  FRIENDLY_NAME = 'Ansible Tower Job Template'.freeze
end
