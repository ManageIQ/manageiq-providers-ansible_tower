ManageIQ::Providers::Awx::Provider.include(ActsAsStiLeafClass)

class ManageIQ::Providers::AnsibleTower::Provider < ManageIQ::Providers::Awx::Provider
  has_one :automation_manager,
          :foreign_key => "provider_id",
          :class_name  => "ManageIQ::Providers::AnsibleTower::AutomationManager",
          :autosave    => true
end
