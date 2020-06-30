shared_examples_for "ansible automation_manager" do
  let(:provider) { FactoryBot.build(:provider_ansible_tower) }
  let(:ansible_automation_manager) { FactoryBot.build(:automation_manager_ansible_tower, :provider => provider) }

  describe "#connect" do
    it "delegates to the provider" do
      expect(provider).to receive(:connect)
      ansible_automation_manager.connect
    end
  end

  context "#pause!, #resume!" do
    before do
      MiqRegion.seed
      Zone.seed
    end

    it "moves provider to maintenance_zone when paused" do
      provider = FactoryBot.create(:provider_ansible_tower, :zone => Zone.default_zone)
      ems = FactoryBot.create(:automation_manager_ansible_tower,
                              :provider => provider,
                              :zone     => Zone.default_zone)

      ems.pause!
      provider.reload

      expect(ems.enabled).to eq(false)
      expect(ems.zone).to eq(Zone.maintenance_zone)
      expect(provider.zone).to eq(Zone.maintenance_zone)
    end

    it "moves provider from maintenance_zone when resumed" do
      ems = FactoryBot.create(:automation_manager_ansible_tower,
                              :enabled           => false,
                              :provider          => FactoryBot.build(:provider_ansible_tower),
                              :zone              => Zone.maintenance_zone,
                              :zone_before_pause => Zone.default_zone)

      ems.resume!
      ems.provider.reload

      expect(ems.enabled).to eq(true)
      expect(ems.zone).to eq(Zone.default_zone)
      expect(ems.provider.zone).to eq(Zone.default_zone)
    end
  end
end
