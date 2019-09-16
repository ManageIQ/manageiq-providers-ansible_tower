shared_examples_for "refresh targeted" do |ansible_provider, manager_class, _ems_type, cassette_path|
  include_context "uses tower_data.yml"

  let(:tower_url) { ENV['TOWER_URL'] || "https://dev-ansible-tower3.example.com/api/v1/" }
  let(:auth_userid) { ENV['TOWER_USER'] || 'testuser' }
  let(:auth_password) { ENV['TOWER_PASSWORD'] || 'secret' }

  let(:auth)                    { FactoryBot.create(:authentication, :userid => auth_userid, :password => auth_password) }
  let(:automation_manager)      { provider.automation_manager }
  let(:provider) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    FactoryBot.create(ansible_provider,
                      :zone       => zone,
                      :url        => tower_url,
                      :verify_ssl => false,).tap { |provider| provider.authentications << auth }
  end
  let(:manager_class) { manager_class }
  let(:cassette_path) { cassette_path }

  let(:targeted_refresh_last_updated) { tower_data[:items]['hello_repo'][:last_updated].utc }

  context "with settings" do
    before do
      VCR.configure do |c|
        c.cassette_library_dir = ManageIQ::Providers::AnsibleTower::Engine.root.join("spec/vcr_cassettes")
      end
      [
        :allow_targeted_refresh   => true,
        :inventory_object_refresh => true,
        :inventory_collections    => {
          :saver_strategy => "batch",
          :use_ar_object  => false,
        },
      ].each do |settings|
        stub_settings_merge(
          :ems_refresh => {
            :ansible_tower_automation => settings
          }
        )
      end
    end

    it "will refresh inventory_root_group" do
      repeat_with_cassette("inventory_root_group") do
        EmsRefresh.refresh([make_target(:inventory_root_groups,
                                        :ems_ref => tower_data[:items]['hello_inventory'][:id])])

        assert_specific_inventory_root_group
      end
    end

    it "will refresh configured_system" do
      repeat_with_cassette("configured_system") do
        EmsRefresh.refresh([make_target(:configured_systems,
                                        :manager_ref => tower_data[:items]['hello_vm'][:id])])

        assert_specific_configured_system
        assert_specific_inventory_root_group
      end
    end

    it "will refresh configuration_script" do
      repeat_with_cassette("configuration_script") do
        EmsRefresh.refresh([make_target(:configuration_scripts,
                                        :manager_ref => tower_data[:items]['hello_template'][:id])])

        assert_specific_configuration_script
        assert_specific_configuration_script_source
        assert_specific_configuration_script_payload
        assert_specific_inventory_root_group
      end
    end

    it "will refresh credential" do
      repeat_with_cassette("credential") do
        EmsRefresh.refresh([make_target(:credentials,
                                        :manager_ref => "1157")])

        assert_specific_amazon_credential
      end
    end

    it "will refresh configuration_workflow" do
      repeat_with_cassette("configuration_workflow") do
        EmsRefresh.refresh [make_target(:configuration_scripts,
                                        :manager_ref => tower_data[:items]['hello_workflow'][:id])]

        assert_specific_configuration_workflow
      end
    end

    it "will refresh configuration_script_sources in batches" do
      # pre-loading needed due to stub_const error
      # https://github.com/rspec/rspec-mocks/issues/1079
      manager_class.parent::Inventory
      manager_class.parent::Inventory::Collector

      repeat_with_cassette("configuration_script_sources_in_batches", :repeat_count => 1) do
        # get all projects first
        connection = automation_manager.connect
        projects = connection.api.projects.all
        expect(projects.count).to eq(tower_data[:total_counts][:projects])

        # create targets
        targets = projects.map do |project|
          make_target(:configuration_script_sources, :manager_ref => project.id.to_s)
        end

        # make targeted refresh in various sized batches
        [1, 2, 100].each do |batch_size|
          stub_const("#{manager_class.parent}::Inventory::Collector::TargetCollection::MAX_FILTER_SIZE", batch_size)

          EmsRefresh.refresh(targets)

          expect(ConfigurationScriptSource.count).to eq(tower_data[:total_counts][:projects])
          ConfigurationScriptSource.destroy_all
        end
      end
    end

    # - Implemented separately in refresher_configuration_script_source_spec
    # it "will refresh configuration_script_sources"
  end

  private

  def repeat_with_cassette(cassette_name, repeat_count: 2)
    repeat_count.times do
      VCR.use_cassette(cassette_path + "/#{cassette_name}") do
        yield
      end
    end
  end

  def assert_specific_inventory_root_group
    expect(inventory(:inventory_root_group)).to have_attributes(:name => "hello_inventory")
  end

  def assert_specific_configured_system
    expect(inventory(:configured_system)).to have_attributes(
      :hostname                => 'hello_vm',
      :virtual_instance_ref    => '4233080d-7467-de61-76c9-c8307b6e4830',
      :inventory_root_group_id => inventory(:inventory_root_group).id
    )
  end

  def assert_specific_configuration_script
    expect(inventory(:configuration_script)).to have_attributes(
      :name                           => 'hello_template',
      :description                    => 'test job',
      :survey_spec                    => {},
      :variables                      => {},
      :configuration_script_source_id => nil,
      :inventory_root_group_id        => inventory(:inventory_root_group).id,
      :parent_id                      => inventory(:configuration_script_payload).id,
    )

    assert_specific_amazon_credential(inventory(:configuration_script, :reload => false))
    assert_specific_machine_credential(inventory(:configuration_script, :reload => false))
    assert_specific_network_credential(inventory(:configuration_script, :reload => false))
  end

  def assert_specific_configuration_workflow
    expect(inventory(:configuration_workflow)).to have_attributes(
      :name        => 'hello_workflow',
      :description => 'test workflow',
      :survey_spec => {},
      :variables   => {},
    )
  end

  def assert_specific_amazon_credential(configuration_script = nil)
    cred = if configuration_script.present?
             configuration_script.authentications.select { |auth| auth.type == manager_class::AmazonCredential.to_s }.first
           else
             inventory(:aws_credential)
           end

    expect(cred).not_to be_nil
    expect(cred).to have_attributes(
      :name   => "hello_aws_cred",
      :userid => "ABC"
    )
  end

  def assert_specific_machine_credential(configuration_script)
    cred = configuration_script.authentications.select { |auth| auth.type == manager_class::MachineCredential.to_s }.first

    expect(cred).not_to be_nil
    expect(cred).to have_attributes(
      :name   => "hello_machine_cred",
      :userid => "admin"
    )
  end

  def assert_specific_network_credential(configuration_script)
    cred = configuration_script.authentications.select { |auth| auth.type == manager_class::NetworkCredential.to_s }.first

    expect(cred).not_to be_nil
    expect(cred).to have_attributes(
      :name   => "hello_network_cred",
      :userid => "admin"
    )
  end

  def assert_specific_scm_credential(configuration_script_source)
    cred = configuration_script_source.authentication

    expect(cred).not_to be_nil
    expect(cred).to have_attributes(
      :name   => "hello_scm_cred",
      :userid => "admin"
    )
  end

  def assert_specific_configuration_script_payload
    expect(inventory(:configuration_script_payload)).to have_attributes(
      :name                           => 'hello_world.yml',
      :configuration_script_source_id => inventory(:configuration_script_source).id
    )
  end

  def assert_specific_configuration_script_source
    expect(inventory(:configuration_script_source)).to have_attributes(
      :name                 => 'hello_repo',
      :description          => '',
      :scm_type             => 'git',
      :scm_url              => 'https://github.com/jameswnl/ansible-examples',
      :scm_branch           => '',
      :scm_clean            => false,
      :scm_delete_on_update => false,
      :scm_update_on_launch => false,
      :status               => "successful"
    )

    assert_specific_scm_credential(inventory(:configuration_script_source, :reload => false))
    assert_specific_configuration_script_source_playbooks(inventory(:configuration_script_source, :reload => false))
  end

  def assert_specific_configuration_script_source_playbooks(configuration_script_source)
    expect(configuration_script_source.configuration_script_payloads.pluck(:manager_ref)).to match_array(tower_data[:items]['hello_repo'][:playbooks])
  end

  def make_target(association, manager_ref)
    InventoryRefresh::Target.new(:association => association,
                                 :manager_id  => automation_manager.id,
                                 :manager_ref => manager_ref)
  end

  def inventory(name, reload: true)
    @inventory ||= {}
    @inventory[name] ||= case name
                         when :aws_credential then manager_class::AmazonCredential.where(:name => 'hello_aws_cred').first
                         when :inventory_root_group then manager_class::Inventory.where(:ems_ref => tower_data[:items]['hello_inventory'][:id]).first
                         when :configuration_script then manager_class::ConfigurationScript.where(:manager_ref => tower_data[:items]['hello_template'][:id]).first
                         when :configuration_script_payload then manager_class::ConfigurationScriptPayload.where(:manager_ref => 'hello_world.yml').first
                         when :configuration_script_source then manager_class::ConfigurationScriptSource.where(:manager_ref => tower_data[:items]['hello_repo'][:id]).first
                         when :configuration_workflow then manager_class::ConfigurationWorkflow.where(:manager_ref => tower_data[:items]['hello_workflow'][:id]).first
                         when :configured_system then manager_class::ConfiguredSystem.where(:manager_ref => tower_data[:items]['hello_vm'][:id]).first
                         end
    @inventory[name].reload if @inventory[name].present? && reload
    @inventory[name]
  end
end
