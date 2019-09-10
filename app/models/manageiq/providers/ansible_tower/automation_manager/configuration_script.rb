class ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript <
  ManageIQ::Providers::AutomationManager::ConfigurationScript

  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::ConfigurationScript
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::TowerApi

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
end
