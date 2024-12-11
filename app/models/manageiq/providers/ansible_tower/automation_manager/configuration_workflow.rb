ManageIQ::Providers::Awx::AutomationManager::ConfigurationWorkflow.include(ActsAsStiLeafClass)

class ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationWorkflow < ManageIQ::Providers::Awx::AutomationManager::ConfigurationWorkflow
  def run_with_miq_job(options, userid = nil)
    options[:name] = "Workflow Template: #{name}"
    options[:ansible_template_id] = id
    options[:userid] = userid || 'system'
    miq_job = ManageIQ::Providers::AnsibleTower::AutomationManager::TemplateRunner.create_job(options)
    miq_job.signal(:start)
    miq_job.miq_task.id
  end

  def self.display_name(number = 1)
    n_('Workflow Template (Ansible Automation Platform)', 'Workflow Templates (Ansible Automation Platform)', number)
  end

  FRIENDLY_NAME = 'Ansible Automation Platform Workflow Job Template'.freeze
end
