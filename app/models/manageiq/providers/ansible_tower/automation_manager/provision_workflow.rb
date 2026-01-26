class ManageIQ::Providers::AnsibleTower::AutomationManager::ProvisionWorkflow < ManageIQ::Providers::Awx::AutomationManager::ProvisionWorkflow
  def dialog_name_from_automate(message = 'get_dialog_name', extra_attrs = {})
    extra_attrs['platform'] ||= 'ansible_tower'
    super
  end
end
