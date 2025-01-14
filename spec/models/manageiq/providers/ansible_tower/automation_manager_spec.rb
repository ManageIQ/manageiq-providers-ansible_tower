describe ManageIQ::Providers::AnsibleTower::AutomationManager do
  it_behaves_like 'ansible automation_manager'

  describe '#catalog_types' do
    let(:ems) { FactoryBot.create(:automation_manager_ansible_tower) }

    it "#catalog_types" do
      expect(ems.catalog_types).to include("generic_ansible_tower")
    end
  end

  context "#pause!" do
    let(:zone) { FactoryBot.create(:zone) }
    let(:ems)  { FactoryBot.create(:automation_manager_ansible_tower, :zone => zone) }

    include_examples "ExtManagementSystem#pause!"
  end

  context "#resume!" do
    let(:zone) { FactoryBot.create(:zone) }
    let(:ems)  { FactoryBot.create(:automation_manager_ansible_tower, :zone => zone) }

    include_examples "ExtManagementSystem#resume!"
  end

  describe ".create_from_params" do
    it "delegates endpoints, zone, name to provider" do
      params = {:zone => FactoryBot.create(:zone), :name => "Ansible Automation Platform"}
      endpoints = [{"role" => "default", "url" => "https://tower", "verify_ssl" => 0}]
      authentications = [{"authtype" => "default", "userid" => "admin", "password" => "smartvm"}]

      automation_manager = described_class.create_from_params(params, endpoints, authentications)

      expect(automation_manager.provider.name).to eq("Ansible Automation Platform")
      expect(automation_manager.provider.endpoints.count).to eq(1)
    end
  end

  describe "#edit_with_params" do
    let(:automation_manager) do
      FactoryBot.build(:automation_manager_ansible_tower, :name => "Ansible Automation Platform", :url => "https://localhost")
    end

    it "updates the provider" do
      params = {:zone => FactoryBot.create(:zone), :name => "Ansible Automation Platform 2"}
      endpoints = [{"role" => "default", "url" => "https://tower", "verify_ssl" => 0}]
      authentications = [{"authtype" => "default", "userid" => "admin", "password" => "smartvm"}]

      provider = automation_manager.provider
      expect(provider.name).to eq("Ansible Automation Platform")
      expect(provider.url).to  eq("https://localhost")

      automation_manager.edit_with_params(params, endpoints, authentications)

      provider.reload
      expect(provider.name).to eq("Ansible Automation Platform 2")
      expect(provider.url).to eq("https://tower")
    end
  end
end
