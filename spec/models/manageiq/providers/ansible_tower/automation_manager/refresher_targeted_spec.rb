describe ManageIQ::Providers::AnsibleTower::AutomationManager::Refresher do
  it_behaves_like 'refresh targeted',
                  :provider_ansible_tower,
                  described_class.parent,
                  :ansible,
                  described_class.name.underscore + '_targeted'
end
