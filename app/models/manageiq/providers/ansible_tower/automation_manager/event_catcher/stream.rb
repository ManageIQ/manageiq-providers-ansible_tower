class ManageIQ::Providers::AnsibleTower::AutomationManager::EventCatcher::Stream < ManageIQ::Providers::Awx::AutomationManager::EventCatcher::Stream
  class ProviderUnreachable < ManageIQ::Providers::BaseManager::EventCatcher::Runner::TemporaryFailure
  end
end
