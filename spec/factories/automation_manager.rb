FactoryBot.define do
  factory :automation_manager_ansible_tower,
  :aliases => ["manageiq/providers/ansible_tower/automation_manager"],
  :class   => "ManageIQ::Providers::AnsibleTower::AutomationManager",
  :parent  => :automation_manager do
    provider :factory => :provider_ansible_tower
  end
end
