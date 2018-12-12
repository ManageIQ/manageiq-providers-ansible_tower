describe ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScriptSource do
  let(:manager) do
    FactoryBot.create(:provider_ansible_tower, :with_authentication).managers.first
  end
  it_behaves_like 'ansible configuration_script_source'
end
