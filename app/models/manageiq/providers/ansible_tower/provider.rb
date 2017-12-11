class ManageIQ::Providers::AnsibleTower::Provider < ::Provider
  include ManageIQ::Providers::AnsibleTower::Shared::Provider

  before_destroy :destroy_manager

  has_one :automation_manager,
          :foreign_key => "provider_id",
          :class_name  => "ManageIQ::Providers::AnsibleTower::AutomationManager",
          :dependent   => :destroy,
          :autosave    => true

  def destroy_manager
    automation_manager.orchestrate_destroy
  end
end
