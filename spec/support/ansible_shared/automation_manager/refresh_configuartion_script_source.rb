shared_examples_for "refresh configuration_script_source" do |ansible_provider, manager_class, ems_type, cassette_path|
  let(:tower_url) { ENV['TOWER_URL'] || "https://dev-ansible-tower3.example.com/api/v1/" }
  let(:auth_userid) { ENV['TOWER_USER'] || 'testuser' }
  let(:auth_password) { ENV['TOWER_PASSWORD'] || 'secret' }

  let(:auth)                    { FactoryGirl.create(:authentication, :userid => auth_userid, :password => auth_password) }
  let(:automation_manager)      { provider.automation_manager }
  let(:provider) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    FactoryGirl.create(ansible_provider,
                       :zone       => zone,
                       :url        => tower_url,
                       :verify_ssl => false,).tap { |provider| provider.authentications << auth }
  end
  let(:manager_class) { manager_class }

  let(:tower_data) { Spec::Support::TowerDataHelper.tower_data }

  let(:hello_repo_id) { tower_data['items']['hello_repo']['id'] }
  let(:hello_repo_last_updated) { tower_data['items']['hello_repo']['last_updated'].utc }
  let(:hello_repo_playbooks) { tower_data['items']['hello_repo']['playbooks'] }
  let(:another_repo_id) { tower_data['items']['another_repo']['id'] }

  let(:hello_repo_playbook_count) { tower_data['counts']['playbooks']['hello_repo'] }

  it "will perform a targeted refresh" do
    credential = FactoryGirl.create(:"#{ems_type}_scm_credential", :name => '2keep')
    automation_manager.credentials << credential
    configuration_script_source = FactoryGirl.create(:"#{ems_type}_configuration_script_source",
                                                     :authentication => credential,
                                                     :manager        => automation_manager,
                                                     :manager_ref    => hello_repo_id)
    configuration_script_source.configuration_script_payloads.create!(:manager_ref => '2b_rm', :name => '2b_rm')
    configuration_script_source_other = FactoryGirl.create(:"#{ems_type}_configuration_script_source",
                                                           :manager_ref => another_repo_id,
                                                           :manager     => automation_manager,
                                                           :name        => 'Dont touch this')

    # When re-recording the cassetes, comment this to default to normal poll sleep time
    stub_const("ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::ConfigurationScriptSource::REFRESH_ON_TOWER_SLEEP", 0.seconds)

    # this is to check if a project will be updated on tower
    last_project_update = hello_repo_last_updated

    Spec::Support::VcrHelper.with_cassette_library_dir(ManageIQ::Providers::AnsibleTower::Engine.root.join("spec/vcr_cassettes")) do
      2.times do
        configuration_script_payloads = configuration_script_source.configuration_script_payloads

        VCR.use_cassette(cassette_path) do
          EmsRefresh.refresh([[configuration_script_source.class.to_s, configuration_script_source.id]])

          expect(automation_manager.reload.last_refresh_error).to be_nil
          expect(automation_manager.configuration_script_sources.count).to eq(2)

          configuration_script_source.reload
          configuration_script_source_other.reload

          last_updated = Time.parse(configuration_script_source.provider_object.last_updated).utc
          expect(last_updated).to be >= last_project_update
          last_project_update = last_updated

          expect(configuration_script_source.name).to eq("hello_repo")
          expect(configuration_script_source.last_updated_on).to eq(last_updated)
          expect(ConfigurationScriptPayload.count).to eq(hello_repo_playbook_count)
          expect(ConfigurationScriptPayload.where(:name => '2b_rm')).to be_empty

          expect(configuration_script_payloads.count).to eq(hello_repo_playbook_count)
          hello_repo_playbooks.each do |playbook|
            expect(configuration_script_payloads.where(:name => playbook).count).to eq(1)
          end

          expect(configuration_script_source.authentication.name).to eq('hello_scm_cred')
          expect(credential.reload).to eq(credential)

          expect(configuration_script_source_other.name).to eq("Dont touch this")
        end
        # check if playbooks will be added back in on the second run
        configuration_script_payloads.destroy_all
      end
    end
  end
end
