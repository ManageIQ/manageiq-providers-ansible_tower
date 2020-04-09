describe ManageIQ::Providers::AnsibleTower::AutomationManager do
  it_behaves_like 'ansible automation_manager'

  describe '#catalog_types' do
    let(:ems) { FactoryBot.create(:automation_manager_ansible_tower) }

    it "#catalog_types" do
      expect(ems.catalog_types).to include("generic_ansible_tower")
    end
  end
end
