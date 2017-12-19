describe ManageIQ::Providers::AnsibleTower::AutomationManager::Refresher do
  let(:more_credential_types) do
    {
      'hello_sat_cred' => 'Satellite6Credential'
    }
  end

  it_behaves_like 'ansible refresher',
                  :provider_ansible_tower,
                  described_class.parent,
                  :ansible_tower_automation,
                  described_class.name.underscore
end
