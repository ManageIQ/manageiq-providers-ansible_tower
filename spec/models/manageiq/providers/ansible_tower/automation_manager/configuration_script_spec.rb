describe ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript do
  let(:provider_with_authentication)       { FactoryBot.create(:provider_ansible_tower, :with_authentication) }
  let(:manager_with_authentication)        { provider_with_authentication.managers.first }
  let(:manager_with_configuration_scripts) { FactoryBot.create(:automation_manager_ansible_tower, :provider, :configuration_script) }

  it_behaves_like 'ansible configuration_script'

  it 'designates orchestration stack type' do
    expect(described_class.stack_type).to eq('Job')
  end
end
