require "ansible_tower_client"

shared_examples_for "ansible provider" do
  describe "#connect" do
    let(:attrs) { {:username => "admin", :password => "smartvm", :verify_ssl => OpenSSL::SSL::VERIFY_PEER} }

    it "with no port" do
      url = "example.com"

      expect(AnsibleTowerClient::Connection).to receive(:new).with(attrs.merge(:base_url => url))
      subject.connect(attrs.merge(:url => url))
    end

    it "with a port" do
      url = "example.com:555"

      expect(AnsibleTowerClient::Connection).to receive(:new).with(attrs.merge(:base_url => url))
      subject.connect(attrs.merge(:url => url))
    end
  end

  describe "#destroy" do
    it "will remove all child objects" do
      subject.automation_manager.configured_systems = [
        FactoryGirl.create(:configured_system, :computer_system =>
          FactoryGirl.create(:computer_system,
                             :operating_system => FactoryGirl.create(:operating_system),
                             :hardware         => FactoryGirl.create(:hardware)))
      ]

      subject.destroy

      expect(Provider.count).to              eq(0)
      expect(ConfiguredSystem.count).to      eq(0)
      expect(ComputerSystem.count).to        eq(0)
      expect(OperatingSystem.count).to       eq(0)
      expect(Hardware.count).to              eq(0)
    end

    it "thru automation_manager will remove all child objects" do
      subject.automation_manager.configured_systems = [
        FactoryGirl.create(:configured_system, :computer_system =>
          FactoryGirl.create(:computer_system,
                             :operating_system => FactoryGirl.create(:operating_system),
                             :hardware         => FactoryGirl.create(:hardware)))
      ]

      expect(ExtManagementSystem.count).to eq(1)
      expect(subject.automation_manager.class.name).to eq("ManageIQ::Providers::AnsibleTower::AutomationManager")
      subject.automation_manager.destroy

      expect(Provider.count).to              eq(1)
      expect(ExtManagementSystem.count).to   eq(0)
      expect(ConfiguredSystem.count).to      eq(0)
      expect(ComputerSystem.count).to        eq(0)
      expect(OperatingSystem.count).to       eq(0)
      expect(Hardware.count).to              eq(0)
    end

    it "thru ems will NOT remove all child objects" do
      subject.automation_manager.configured_systems = [
        FactoryGirl.create(:configured_system, :computer_system =>
          FactoryGirl.create(:computer_system,
                             :operating_system => FactoryGirl.create(:operating_system),
                             :hardware         => FactoryGirl.create(:hardware)))
      ]

      expect(ExtManagementSystem.count).to eq(1)
      expect(ExtManagementSystem.first.class.name).to eq("ManageIQ::Providers::AnsibleTower::AutomationManager")
      ExtManagementSystem.first.destroy

      expect(Provider.count).to              eq(1)
      expect(ExtManagementSystem.count).to   eq(0)
      expect(ConfiguredSystem.count).to      eq(1)
      expect(ComputerSystem.count).to        eq(1)
      expect(OperatingSystem.count).to       eq(1)
      expect(Hardware.count).to              eq(1)
    end
  end

  context "#url=" do
    it "with full URL" do
      subject.url = "https://server.example.com:1234/api/v1"
      expect(subject.url).to eq("https://server.example.com:1234/api/v1")
    end

    it "missing scheme" do
      subject.url = "server.example.com:1234/api/v1"
      expect(subject.url).to eq("https://server.example.com:1234/api/v1")
    end

    it "works with #update_attributes" do
      subject.update_attributes(:url => "server.example.com")
      subject.update_attributes(:url => "server2.example.com")
      expect(Endpoint.find(subject.default_endpoint.id).url).to eq("https://server2.example.com/api/v1")
    end
  end

  it "with only hostname" do
    subject.url = "server.example.com"
    expect(subject.url).to eq("https://server.example.com/api/v1")
  end
end
