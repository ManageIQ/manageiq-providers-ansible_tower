describe ManageIQ::Providers::AnsibleTower::AutomationManager do
  it_behaves_like 'ansible automation_manager'

  context 'catalog types' do
    let(:ems) { FactoryBot.create(:automation_manager_ansible_tower) }

    it "#supported_catalog_types" do
      expect(ems.supported_catalog_types).to eq(%w(generic_ansible_tower))
    end
  end
end
