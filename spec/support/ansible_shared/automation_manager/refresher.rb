shared_examples_for "ansible refresher" do |ansible_provider, manager_class, ems_type, cassette_path|
  # Maintaining cassettes for new specs
  #
  # Option #1
  # ========
  # Update: re-create expected set of Tower objects and re-record cassettes
  # 1. Modify the rake task lib/tasks_private/spec_helper.rake to modify the objects for new spec
  # 2. rake manageiq:providers:ansible_tower:populate_tower
  #    (refer to the task doc for detail)
  # 2. remove the old cassette
  # 3. run the spec to create the cassette
  # 4. update the expectations
  # 5. change credentials in cassettes before commit
  #
  # Option #2
  # ========
  # To re-record cassettes or to add cassettes you can add another inner `VCR.use_cassette` block to the
  # 'will perform a full refresh' example. When running specs, new requests are recorded to the innermost cassette and
  # can be played back from  any level of nesting (it tries the innermost cassette first, then searches up the parent
  # chain) - http://stackoverflow.com/a/13425826
  #
  # To add a new cassette
  #   * add another block (innermost) with an empty cassette
  #   * change existing cassettes to use your working credentials
  #   * run the specs to create a new cassette
  #   * change new and existing cassettes to use default credentials
  #
  # To re-record a cassette
  #   * temporarily make the cassette the innermost one (see above about recording)
  #   * rm cassette ; run specs
  #   * change back the order of cassettes
  #
  #
  # To change credentials in cassettes
  # ==================================
  # replace with defaults - before committing
  # ruby -pi -e 'gsub /yourdomain.com/, "example.com"; gsub /admin:smartvm/, "testuser:secret"' spec/vcr_cassettes/manageiq/providers/ansible_tower/automation_manager/*.yml
  # replace with your working credentials
  # ruby -pi -e 'gsub /example.com/, "yourdomain.com"; gsub /testuser:secret/, "admin:smartvm"' spec/vcr_cassettes/manageiq/providers/ansible_tower/automation_manager/*.yml
  include_context "uses tower_data.yml"

  let(:tower_url) { ENV['TOWER_URL'] || "https://example.com/api/v1/" }
  let(:auth_userid) { ENV['TOWER_USER'] || 'testuser' }
  let(:auth_password) { ENV['TOWER_PASSWORD'] || 'secret' }

  let(:auth)                    { FactoryGirl.create(:authentication, :userid => auth_userid, :password => auth_password) }
  let(:automation_manager)      { provider.automation_manager }
  let(:expected_counterpart_vm) { FactoryGirl.create(:vm, :uid_ems => "4233080d-7467-de61-76c9-c8307b6e4830") }
  let(:provider) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    FactoryGirl.create(ansible_provider,
                       :zone       => zone,
                       :url        => tower_url,
                       :verify_ssl => false,).tap { |provider| provider.authentications << auth }
  end
  let(:manager_class) { manager_class }

  let(:api_version) { tower_data[:config][:version] }

  let(:host_count) { tower_data[:total_counts][:hosts] }
  let(:job_template_count) { tower_data[:total_counts][:job_templates] }
  let(:workflow_job_template_count) { tower_data[:total_counts][:workflow_job_templates] }
  let(:inventory_count) { tower_data[:total_counts][:inventories] }
  let(:project_count) { tower_data[:total_counts][:projects] }
  let(:playbook_count) { tower_data[:total_counts][:playbooks] }
  let(:credential_count) { tower_data[:total_counts][:credentials] }

  let(:hello_inventory_id) { tower_data[:items]['hello_inventory'][:id] }
  let(:hello_repo_id) { tower_data[:items]['hello_repo'][:id] }
  let(:hello_repo_playbooks) { tower_data[:items]['hello_repo'][:playbooks] }
  let(:hello_repo_playbook_count) { tower_data[:items]['hello_repo'][:playbooks].count }
  let(:hello_repo_status) { tower_data[:items]['hello_repo'][:status] }
  let(:hello_template_id) { tower_data[:items]['hello_template'][:id] }
  let(:hello_template_with_survey_id) { tower_data[:items]['hello_template_with_survey'][:id] }
  let(:hello_vm_id) { tower_data[:items]['hello_vm'][:id] }

  it ".ems_type" do
    expect(described_class.ems_type).to eq(ems_type)
  end

  it "will remove all objects if an empty collection is returned by tower" do
    mock_api = double
    mock_collection = double(:all => [])
    allow(mock_api).to receive(:version).and_return(api_version)
    allow(mock_api).to receive_messages(
      :inventories            => mock_collection,
      :hosts                  => mock_collection,
      :job_templates          => mock_collection,
      :workflow_job_templates => mock_collection,
      :projects               => mock_collection,
      :credentials            => mock_collection,
    )
    allow(automation_manager.provider).to receive_message_chain(:connect, :api).and_return(mock_api)
    automation_manager.configuration_script_sources.create!
    EmsRefresh.refresh(automation_manager)

    expect(ConfigurationScriptSource.count).to eq(0)
  end

  it "will perform a full refresh" do
    expected_counterpart_vm

    Spec::Support::VcrHelper.with_cassette_library_dir(ManageIQ::Providers::AnsibleTower::Engine.root.join("spec/vcr_cassettes")) do
      2.times do
        # to re-record cassettes see comment at the beginning of this file
        VCR.use_cassette(cassette_path) do
          EmsRefresh.refresh(automation_manager)
          expect(automation_manager.reload.last_refresh_error).to be_nil
        end
        assert_counts
        assert_configured_system
        assert_configuration_script_with_nil_survey_spec
        assert_configuration_script_with_survey_spec
        assert_configuration_workflow
        assert_inventory_root_group
        assert_configuration_script_sources
        assert_playbooks
        assert_credentials
      end
    end
  end

  it "limits the size of configuration_script_source.last_update_error" do
    stub_const("#{ManageIQ::Providers::AnsibleTower::Shared::Inventory::Parser::AutomationManager}::ERROR_MAX_SIZE", 20)

    Spec::Support::VcrHelper.with_cassette_library_dir(ManageIQ::Providers::AnsibleTower::Engine.root.join("spec/vcr_cassettes")) do
      VCR.use_cassette(cassette_path) do
        EmsRefresh.refresh(automation_manager)
      end
    end

    failed_configuration_script_source = automation_manager.configuration_script_sources.find_by(:name => 'failed_repo')
    expect(failed_configuration_script_source).to have_attributes(
      :last_update_error => "Using /etc/ansible/a"
    )
  end

  def assert_counts
    expect(Provider.count).to                                         eq(1)
    expect(automation_manager).to                                     have_attributes(:api_version => api_version)
    expect(automation_manager.configured_systems.count).to            eq(host_count)
    expect(automation_manager.configuration_scripts.count).to         eq(workflow_job_template_count + job_template_count)
    expect(manager_workflows.count).to                                eq(workflow_job_template_count)
    expect(manager_job_templates.count).to                            eq(job_template_count)
    expect(automation_manager.inventory_groups.count).to              eq(inventory_count)
    expect(automation_manager.configuration_script_sources.count).to  eq(project_count)
    expect(automation_manager.configuration_script_payloads.count).to eq(playbook_count)
    expect(automation_manager.credentials.count).to                   eq(credential_count)
  end

  def assert_credentials
    expect(expected_configuration_script.authentications.count).to eq(3)

    # vault_credential
    vault_credential = Authentication.find_by(:type => manager_class::VaultCredential.name, :manager_ref => '1035')
    expect(vault_credential.options.keys).to match_array([:vault_password])
    expect(vault_credential.options[:vault_password]).not_to be_empty
    expect(vault_credential.name).to eq("hello_vault_cred")

    # machine_credential
    machine_credential = expected_configuration_script.authentications.find_by(
      :type => manager_class::MachineCredential.name
    )
    expect(machine_credential).to have_attributes(
      :name   => "hello_machine_cred",
      :userid => "admin",
    )
    expect(machine_credential.options.keys).to match_array(%i(become_method become_password become_username ssh_key_data ssh_key_unlock))
    expect(machine_credential.options[:become_method]).to eq('')
    expect(machine_credential.options[:become_username]).to eq('')

    # network_credential
    network_credential = expected_configuration_script.authentications.find_by(
      :type => manager_class::NetworkCredential.name
    )
    expect(network_credential).to have_attributes(
      :name   => "hello_network_cred",
      :userid => "admin",
    )
    expect(network_credential.options.keys).to match_array([:authorize, :authorize_password, :ssh_key_data, :ssh_key_unlock])

    cloud_credential = expected_configuration_script.authentications.find_by(
      :type => manager_class::AmazonCredential.name
    )
    expect(cloud_credential).to have_attributes(
      :name   => "hello_aws_cred",
      :userid => "ABC",
    )
    expect(cloud_credential.options.keys).to match_array([:security_token])

    # scm_credential
    scm_credential = expected_configuration_script_source.authentication
    expect(scm_credential).to have_attributes(
      :name   => "hello_scm_cred",
      :userid => "admin"
    )
    expect(scm_credential.options.keys).to match_array([:ssh_key_data, :ssh_key_unlock])

    # other credential types
    openstack_cred = automation_manager.credentials.find_by(:name => 'hello_openstack_cred')
    expect(openstack_cred.type.split('::').last).to eq("OpenstackCredential")
    gce_cred = automation_manager.credentials.find_by(:name => 'hello_gce_cred')
    expect(gce_cred.type.split('::').last).to eq("GoogleCredential")
    azure_cred = automation_manager.credentials.find_by(:name => 'hello_azure_cred')
    expect(azure_cred.type.split('::').last).to eq("AzureCredential")
    if defined?(more_credential_types)
      more_credential_types.each do |name, type|
        cred = automation_manager.credentials.find_by(:name => name)
        expect(cred.type.split('::').last).to end_with(type)
      end
    end
  end

  def assert_playbooks
    configuration_script_payloads = expected_configuration_script_source.configuration_script_payloads
    expect(configuration_script_payloads.count).to eq(hello_repo_playbook_count)
    configuration_script_payloads.each do |payload|
      expect(payload).to be_an_instance_of(manager_class::Playbook)
    end
    expect(configuration_script_payloads.map(&:name).sort).to eq(hello_repo_playbooks.sort)
  end

  def assert_configuration_script_sources
    # Project with a successful last update job.
    expect(expected_configuration_script_source).to be_an_instance_of(manager_class::ConfigurationScriptSource)
    expect(expected_configuration_script_source).to have_attributes(
      :name                 => 'hello_repo',
      :description          => '',
      :scm_type             => 'git',
      :scm_url              => 'https://github.com/jameswnl/ansible-examples',
      :scm_branch           => '',
      :scm_clean            => false,
      :scm_delete_on_update => false,
      :scm_update_on_launch => false,
      :status               => hello_repo_status,
      :last_update_error    => nil
    )
    expect(expected_configuration_script_source.authentication.name).to eq('hello_scm_cred')

    # Project without any last update job.
    jobless_configuration_script_source = automation_manager.configuration_script_sources.find_by(:name => 'jobless_repo')
    expect(jobless_configuration_script_source).to be_an_instance_of(manager_class::ConfigurationScriptSource)
    expect(jobless_configuration_script_source).to have_attributes(
      :name                 => 'jobless_repo',
      :description          => '',
      :scm_type             => 'git',
      :scm_url              => 'https://github.com/jameswnl/ansible-examples',
      :scm_branch           => '',
      :scm_clean            => false,
      :scm_delete_on_update => false,
      :scm_update_on_launch => false,
      :status               => 'successful',
      :last_update_error    => nil
    )
    expect(jobless_configuration_script_source.authentication.name).to eq('hello_scm_cred')

    # Project with failed last update job.
    failed_configuration_script_source = automation_manager.configuration_script_sources.find_by(:name => 'failed_repo')
    expect(failed_configuration_script_source).to be_an_instance_of(manager_class::ConfigurationScriptSource)
    expect(failed_configuration_script_source).to have_attributes(
      :name                 => 'failed_repo',
      :description          => '',
      :scm_type             => 'git',
      :scm_url              => 'https://github.com/jameswnl/ansible-examplez',
      :scm_branch           => '',
      :scm_clean            => false,
      :scm_delete_on_update => false,
      :scm_update_on_launch => false,
      :status               => 'failed'
    )
    # We don't need to compare the whole last_update_error dump because updating is tedious. And when update is successful, this field will be nil.
    # A sample last_update_error is as follows:
    # "Using /etc/ansible/ansible.cfg as config file\r\n[DEPRECATION WARNING]: DEFAULT_ASK_SUDO_PASS option, In favor of become which \r\nis a generic framework . This feature will be removed in version 2.8. \r\nDeprecation warnings can be disabled by setting deprecation_warnings=False in \r\nansible.cfg.\r\n\r\nPLAY [all] *********************************************************************\r\n\r\nTASK [delete project directory before update] **********************************\r\nskipping: [localhost]\r\n\r\nTASK [update project using git and accept hostkey] *****************************\r\nskipping: [localhost]\r\n\r\nTASK [Set the git repository version] ******************************************\r\nskipping: [localhost]\r\n\r\nTASK [update project using git] ************************************************\r\nfatal: [localhost]: FAILED! => {\"changed\": false, \"cmd\": \"/usr/bin/git clone --origin origin 'https://$encrypted$:$encrypted$@github.com/jameswnl/ansible-examplez' /var/lib/awx/projects/_372__failed_repo\", \"failed\": true, \"msg\": \"remote: Invalid username or password.\\nfatal: Authentication failed for 'https://$encrypted$:$encrypted$@github.com/jameswnl/ansible-examplez/'\", \"rc\": 128, \"stderr\": \"remote: Invalid username or password.\\nfatal: Authentication failed for 'https://$encrypted$:$encrypted$@github.com/jameswnl/ansible-examplez/'\\n\", \"stderr_lines\": [\"remote: Invalid username or password.\", \"fatal: Authentication failed for 'https://$encrypted$:$encrypted$@github.com/jameswnl/ansible-examplez/'\"], \"stdout\": \"Cloning into '/var/lib/awx/projects/_372__failed_repo'...\\n\", \"stdout_lines\": [\"Cloning into '/var/lib/awx/projects/_372__failed_repo'...\"]}\r\n\r\nPLAY RECAP *********************************************************************\r\nlocalhost                  : ok=0    changed=0    unreachable=0    failed=1   \r\n\r\n"
    expect(failed_configuration_script_source.last_update_error.first(45)).to eq("Using /etc/ansible/ansible.cfg as config file")
    expect(failed_configuration_script_source.authentication.name).to eq('hello_scm_cred')
  end

  def assert_configured_system
    expect(expected_configured_system).to have_attributes(
      :type                 => manager_class::ConfiguredSystem.name,
      :hostname             => "hello_vm",
      :manager_ref          => hello_vm_id.to_s,
      :virtual_instance_ref => "4233080d-7467-de61-76c9-c8307b6e4830",
    )
    expect(expected_configured_system.counterpart).to          eq(expected_counterpart_vm)
    expect(expected_configured_system.inventory_root_group).to eq(expected_inventory_root_group)
  end

  def assert_configuration_script_with_nil_survey_spec
    expect(expected_configuration_script).to have_attributes(
      :name        => "hello_template",
      :description => "test job",
      :manager_ref => hello_template_id.to_s,
    )
    expect(expected_configuration_script.parent.configuration_script_source.manager_ref).to eq(hello_repo_id.to_s)
  end

  def assert_configuration_script_with_survey_spec
    system = automation_manager.configuration_scripts.where(:name => "hello_template_with_survey").first
    expect(system).to have_attributes(
      :name        => "hello_template_with_survey",
      :description => "test job with survey spec",
      :manager_ref => hello_template_with_survey_id.to_s,
      :variables   => {}
    )
    survey = system.survey_spec
    expect(survey).to be_a Hash
    expect(survey['spec'].first['question_name']).to eq('example question')
  end

  def assert_configuration_workflow
    expect(expected_configuration_workflow).to have_attributes(
      :name        => "hello_workflow",
      :manager_ref => "402",
      :survey_spec => {},
      :variables   => {},
    )
  end

  def assert_inventory_root_group
    expect(expected_inventory_root_group).to have_attributes(
      :name    => "hello_inventory",
      :ems_ref => hello_inventory_id.to_s,
      :type    => "ManageIQ::Providers::AutomationManager::InventoryRootGroup",
    )
  end

  private

  def expected_configured_system
    @expected_configured_system ||= automation_manager.configured_systems.where(:hostname => "hello_vm").first
  end

  def expected_configuration_script
    @expected_configuration_script ||= automation_manager.configuration_scripts.where(:name => "hello_template").first
  end

  def expected_configuration_workflow
    @expected_configuration_workflow ||= automation_manager.configuration_scripts.where(:name => "hello_workflow").first
  end

  def expected_inventory_root_group
    @expected_inventory_root_group ||= automation_manager.inventory_groups.where(:name => "hello_inventory").first
  end

  def expected_configuration_script_source
    @expected_configuration_script_source ||= automation_manager.configuration_script_sources.find_by(:name => 'hello_repo')
  end

  def manager_workflows
    automation_manager.configuration_scripts.select { |e| e.type.split('::').last == 'ConfigurationWorkflow' }
  end

  def manager_job_templates
    automation_manager.configuration_scripts.select { |e| e.type.split('::').last == 'ConfigurationScript' }
  end
end
