module ManageIQ::Providers::AnsibleTower::AutomationManager::EventParser
  extend ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::EventParser

  def self.event_type
    "ansible_tower"
  end

  def self.source
    "ANSIBLE_TOWER"
  end
end
