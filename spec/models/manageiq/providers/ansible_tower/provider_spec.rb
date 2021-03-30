require "ansible_tower_client"

describe ManageIQ::Providers::AnsibleTower::Provider do
  subject { FactoryBot.create(:provider_ansible_tower) }
  describe "#connect" do
    let(:attrs) { {:username => "admin", :password => "smartvm", :verify_ssl => OpenSSL::SSL::VERIFY_PEER} }

    it "with no port" do
      url = "example.com"
      expected_url = "https://example.com/api/v2"

      expect(AnsibleTowerClient::Connection).to receive(:new).with(attrs.merge(:base_url => expected_url))
      subject.connect(attrs.merge(:url => url))
    end

    it "with a port" do
      url = "example.com:555"
      expected_url = "https://example.com:555/api/v2"

      expect(AnsibleTowerClient::Connection).to receive(:new).with(attrs.merge(:base_url => expected_url))
      subject.connect(attrs.merge(:url => url))
    end

    it "with an explicit api path" do
      url = "example.com/api/v1"
      expected_url = "https://example.com/api/v1"

      expect(AnsibleTowerClient::Connection).to receive(:new).with(attrs.merge(:base_url => expected_url))
      subject.connect(attrs.merge(:url => url))
    end

    it "with an explicit scheme" do
      url = "http://example.com"
      expected_url = "http://example.com/api/v2"

      expect(AnsibleTowerClient::Connection).to receive(:new).with(attrs.merge(:base_url => expected_url))
      subject.connect(attrs.merge(:url => url))
    end
  end

  describe "#destroy" do
    it "will remove all child objects" do
      subject.automation_manager.configured_systems = [
        FactoryBot.create(:configured_system_automation_manager,
                           :computer_system => FactoryBot.create(
                             :computer_system,
                             :operating_system => FactoryBot.create(:operating_system),
                             :hardware         => FactoryBot.create(:hardware)
                           ))
      ]

      subject.destroy

      expect(Provider.count).to              eq(0)
      expect(ConfiguredSystem.count).to      eq(0)
      expect(ComputerSystem.count).to        eq(0)
      expect(OperatingSystem.count).to       eq(0)
      expect(Hardware.count).to              eq(0)
    end
  end
end
