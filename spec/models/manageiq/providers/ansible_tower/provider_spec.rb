describe ManageIQ::Providers::AnsibleTower::Provider do
  subject { FactoryBot.create(:provider_ansible_tower) }

  it_behaves_like 'ansible provider'
end
