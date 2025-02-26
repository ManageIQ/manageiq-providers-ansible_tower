ManageIQ::Providers::Awx::AutomationManager::Credential.include(ActsAsStiLeafClass)

class ManageIQ::Providers::AnsibleTower::AutomationManager::Credential < ManageIQ::Providers::Awx::AutomationManager::Credential
  # Authentication is associated with EMS through resource_id/resource_type
  # Alias is to make the AutomationManager code more uniformly as those
  # CUD operations in the TowerApi concern

  alias_attribute :manager_id, :resource_id

  supports :create

  FRIENDLY_NAME = 'Ansible Automation Platform Credential'.freeze

  def manager
    resource
  end

  def manager=(object)
    self.resource = object
  end
end
