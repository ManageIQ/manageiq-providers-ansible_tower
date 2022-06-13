ManageIQ::Providers::Awx::AutomationManager::ConfigurationScript.include(ActsAsStiLeafClass)

class ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript <
  ManageIQ::Providers::Awx::AutomationManager::ConfigurationScript

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

  FRIENDLY_NAME = 'Ansible Tower Job Template'.freeze
end
