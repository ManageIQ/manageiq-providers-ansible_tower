namespace :spec do
  desc "Populate expected Tower objects for casssettes and spec tests"
  task :populate_tower do
    tower_host = ENV['TOWER_URL'] ||"https://dev-ansible-tower3.example.com/api/v2/"
    id = ENV['TOWER_USER'] || 'testuser'
    password = ENV['TOWER_PASSWORD'] || 'secret'
    populate = PopulateTower.new(tower_host, id, password)

    populate.create_dataset
    populate.counts
    populate.to_file(ManageIQ::Providers::Awx::Engine.root.join("spec/support/tower_data.yml"))
  end

  desc "Get counts of various Tower objects"
  task :tower_counts do
    tower_host = ENV['TOWER_URL'] || "https://dev-ansible-tower3.example.com/api/v2/"
    id = ENV['TOWER_USER'] || 'testuser'
    password = ENV['TOWER_PASSWORD'] || 'secret'
    PopulateTower.new(tower_host, id, password).counts
  end
end

class PopulateTower
  # This is to create a set of objects in Tower and the objects will be captured in a vcr cassette for
  # refresh spec tests. If we need to update the cassette, we can update/rerun this script to modify the objects
  # and so spec expectations can be updated (hopefully) easily
  #
  # It will print out object counts that are needed for the spec
  # Sample output on console
  #
  # === Re-creating Tower objects ===
  #   deleting old spec_test_org: /api/v1/organizations/39/
  # Created name=spec_test_org               manager_ref/ems_ref= 40        url=/api/v1/organizations/40/
  # Created name=hello_scm_cred              manager_ref/ems_ref= 136       url=/api/v1/credentials/136/
  # Created name=hello_machine_cred          manager_ref/ems_ref= 137       url=/api/v1/credentials/137/
  # Created name=hello_vault_cred            manager_ref/ems_ref= 138       url=/api/v1/credentials/138/
  # Created name=hello_aws_cred              manager_ref/ems_ref= 139       url=/api/v1/credentials/139/
  # Created name=hello_network_cred          manager_ref/ems_ref= 140       url=/api/v1/credentials/140/
  # Created name=hello_inventory             manager_ref/ems_ref= 110       url=/api/v1/inventories/110/
  # Created name=hello_vm                    manager_ref/ems_ref= 249       url=/api/v1/hosts/249/
  # Created name=hello_repo                  manager_ref/ems_ref= 591       url=/api/v1/projects/591/
  #   deleting old hello_template: /api/v1/job_templates/589/
  # Created name=hello_template              manager_ref/ems_ref= 592       url=/api/v1/job_templates/592/
  #   deleting old hello_template_with_survey: /api/v1/job_templates/590/
  # Created name=hello_template_with_survey  manager_ref/ems_ref= 593       url=/api/v1/job_templates/593/
  # created /api/v1/job_templates/594/ survey_spec
  # Created name=failed_repo                 manager_ref/ems_ref= 594       url=/api/v1/projects/594/
  # Created name=jobless_repo                manager_ref/ems_ref= 595       url=/api/v1/projects/595/
  # === Object counts ===
  # configuration_script           (job_templates)     : 120
  # configuration_script_source    (projects)          : 32
  # configured_system              (hosts)             : 133
  # inventory_group                (inventories)       : 29
  # credential                     (credentials)       : 47
  # configuration_script_payload   (playbooks)         : 139
  #     hello_repo                                     : 61
  #
  require 'faraday'
  require 'faraday/follow_redirects'

  MAX_TRIES = ENV["MAX_TRIES"] || 10
  TRY_SLEEP = ENV["TRY_SLEEP"] || 2
  DEL_SLEEP = ENV["DEL_SLEEP"] || 20

  def initialize(tower_host, id, password)
    @conn = Faraday.new(tower_host, :ssl => {:verify => false}) do |c|
      c.request :json
      c.use(Faraday::FollowRedirects::Middleware, :limit => 3, :standards_compliant => true)
      c.use(Faraday::Response::RaiseError)
      c.adapter(Faraday.default_adapter)
      c.basic_auth(id, password)
    end

    @tower_data = {}

    uri = '/api/v2/config'
    config = get_obj(uri)
    @version = Gem::Version.new(config['version'])
    @tower_data[:config] = { :version => config['version'] }

    uri = '/api/v2/me'
    me = get_obj(uri)
    @tower_data[:user] = { :id => me['results'].first['id'] }
  end

  def v3_2?
    @version >= Gem::Version.new('3.2')
  end

  def to_file(filename)
    File.write(filename, @tower_data.to_yaml)
  end

  def create_obj(uri, data)
    del_obj(uri, data[:name])
    obj = JSON.parse(@conn.post(uri, data).body)
    puts "Created name=#{obj['name'].ljust(27)} manager_ref/ems_ref=#{obj['id'].to_s.ljust(10)} url=#{obj['url']}"

    obj
  end

  def del_obj(uri, match_name)
    obj = get_obj(uri)

    if (item = obj['results'].find { |i| i['name'] == match_name })
      puts "Deleting old #{item['name']}: #{item['url']}"
      @conn.delete(item['url'])
      sleep(DEL_SLEEP) # without sleep, sometimes subsequent create will return 400. Seems the deletion has some delay in Tower
    elsif obj['next']
      del_obj(obj['next'], match_name)
    end
  end

  def get_obj(uri)
    JSON.parse(@conn.get(uri).body)
  end

  def try_get_obj_until(uri)
    current_try = 1
    loop do
      raise "Requested operation did not finish even after #{current_try} tries." if current_try > MAX_TRIES

      obj = get_obj(uri)
      return obj if yield obj

      current_try = current_try.succ
      sleep(TRY_SLEEP)
    end
  end

  def wait_for_project_update(project)
    last_update_uri = nil
    try_get_obj_until(project['url']) do |body|
      last_update_uri = body['related']['last_update']
      last_update_uri.present?
    end

    # Wait until the "hello_repo" update finishes.
    try_get_obj_until(last_update_uri) do |body|
      raise "“#{project['name']}” cloning failed." if body['failed']
      body['finished'].present?
    end
  end

  def create_dataset
    ssh_key_data = <<~PRIVATEKEY
      -----BEGIN RSA PRIVATE KEY-----
      MIIEowIBAAKCAQEArIIYuT+hC2dhPaSx68zTxsh5OJ3byVLNoX7urk8XU20OjlK4
      7++J7qqkHojXadRZrJI69/BFteqOpLr16fAuTdPnEV1dIolEApT9Gd5sEMb4SFFc
      QmZPtOCuFMRjweQBVqAFboUDpzp1Yosjyiw34JWaT8n2SVYjgFB/6SZt9/r/ZHjU
      qOnQi/VY1Zp6eWtjW+LpverzCDS7EAv06OLeu9CZtKLNl8DcgcCvCbuONPCsbaSv
      FtK8kw4Ev/oJvoYa3RbMphx9dfj8WB0xOcdlDmJLlvqw/iuBX0Ktslm/nADcPcxK
      sd37i8Ds2BRVIlr7F3Pblh77TIP+KWzM0lVs1wIDAQABAoIBAAdpj6ZmFYVn68W6
      TerT4kWoV40XO1prNGq8CYVz4Iy1Iur6ovesU0DuFB87wgXKGhBQODhvGo+2hGqP
      ngFvUI4HjOYyHM5fF40E2dtCs2IFKqXw2QYBX2tmPBSoW6D5KxWNyq31CTMmT+Ts
      FZ2aSMxdoUPMaci86smYq+ZYwGDnVfp2Da5G/GnvdmN+x51mMku5hETBMCOpR+n9
      Z4bYnayVGyLXBJvwhx3pdIprwzAvoiySFjp/tFk+knxiPK84dJ3tIfdtgXmf1Cp9
      pEqDQR3lnvwW0LrBG3c6MiJRlp+Pl3EOZNMLdmsaKODnInwO2U5BNPQuVHPdrObD
      1GXxcAECgYEA3xkFdbQ+I6QZH5OSNxPKRPcqcYuYewTwQKmiL3mSoICfV9dRNV3e
      ewQpcca7h9dcjTtdyx8PfvCNFR/uh/FhMw+kRXb4bdKDbDrKcQ9x23RFatbsgN14
      q90a6FaEOjOXf0TiTNqP/LTFry1x2r1ZCDLtVcg5zWM/iwUgrO5qOJkCgYEAxfMV
      ijLKtBg8Mbdhb2F29vIxMokZS++AhEjWuWl7d/DCApjCXzrfMaHnBC6b4Oppubkp
      i40KnkaaDSy03U4hpcSPoPONbv2Fw4o/88ml71DF44D7kXCIFjSMvPLEtU2qLl4z
      o4dHUSbtycBzn+wou+IdgPNqNnBYvl/eBNHvBu8CgYBQJ3M4uMtijsCgAasUsr2H
      Ta4oIVllSX7wHIIywGEX3V5idu+sVs9qLzKcuCQESDHuZBfstHoix1ZI8rIGkYi0
      ibghZP8Ypful1PGK8Vuc1wdhvVo3alrClKvoMb1ME+EoTp1ns1bsGh60M4Wma0Uj
      lviCS2/JBRF9Zxg4SWhMcQKBgQC3PLABv8a4M371HqXJLtWq/sLf3t1V15yF1888
      zxIGEw3kzXeQI7UcAp0Q1/xflV7NF0QH9EWSAhT0gR/jhEHNa0jxWsLfrTs3qTBO
      AanjAEhOssUs+phexcJJ3giNNBmG1pjClaVEz95qVgYyUa/bTBK3nZwCTLk5cRDa
      MWMsbQKBgCaNkKxH/gZBxVGbnjxbaxTGGq2TxNrKcKWEY4aIybcJ1kM0+UctHPy2
      ixDk3cLUN9/a24A9BI+3GkyuX9LmubW/HqmSErIxnw6fx8OGUsVc/oJxJFbJjXQv
      QS4PQZOVkJOn3sZr4hlMMLEKA7NSP9O9BiXCQIycrCDN6YlZ+0/c
      -----END RSA PRIVATE KEY-----
    PRIVATEKEY

    puts "=== Re-creating Tower objects ==="

    @tower_data[:items] = {}

    # create test organization
    uri = '/api/v2/organizations/'
    data = {
      :name        => 'spec_test_org',
      :description => 'for miq spec tests'
    }
    organization = create_obj(uri, data)
    @tower_data[:items][data[:name]] = { :id => organization['id'] }

    # create scm cred
    uri = '/api/v2/credentials/'
    data = {
      :name         => 'hello_scm_cred',
      :kind         => 'scm',
      :username     => 'admin',
      :password     => 'abc',
      :organization => organization['id']
    }
    scm_credential = create_obj(uri, data)

    # create machine cred
    data = {
      :name         => 'hello_machine_cred',
      :kind         => 'ssh',
      :username     => 'admin',
      :password     => 'abc',
      :organization => organization['id']
    }
    machine_credential = create_obj(uri, data)

    # create vault cred
    data = {
      :name           => 'hello_vault_cred',
      :kind           => 'ssh',
      :vault_password => 'abc',
      :organization   => organization['id']
    }
    _vault_credential = create_obj(uri, data)

    # create network cred
    data = {
      :name         => 'hello_network_cred',
      :kind         => 'net',
      :username     => 'admin',
      :password     => 'abc',
      :organization => organization['id']
    }
    network_credential = create_obj(uri, data)

    # create cloud aws cred
    data = {
      :name         => 'hello_aws_cred',
      :kind         => 'aws',
      :username     => 'ABC',
      :password     => 'abc',
      :organization => organization['id']
    }
    aws_credential = create_obj(uri, data)

    # create cloud openstack cred
    data = {
      :name         => 'hello_openstack_cred',
      :kind         => 'openstack',
      :username     => 'hello_rack',
      :password     => 'abc',
      :host         => 'openstack.com',
      :project      => 'hello_rack',
      :organization => organization['id']
    }
    _openstack_credential = create_obj(uri, data)

    # create cloud google cred
    data = {
      :name         => 'hello_gce_cred',
      :kind         => 'gce',
      :username     => 'hello_gce@gce.com',
      :ssh_key_data => ssh_key_data,
      :project      => 'squeamish-ossifrage-123',
      :organization => organization['id']
    }
    _gce_credential = create_obj(uri, data)

    # create cloud azure(RM) cred
    data = {
      :name         => 'hello_azure_cred',
      :kind         => 'azure_rm',
      :username     => 'admin',
      :password     => 'abc',
      :subscription => 'sub_id',
      :tenant       => 'ten_id',
      :secret       => 'my_secret',
      :client       => 'cli_id',
      :organization => organization['id']
    }
    _azure_rm_credential = create_obj(uri, data)

    # create cloud satellite6 cred
    data = {
      :name         => 'hello_sat_cred',
      :kind         => 'satellite6',
      :username     => 'admin',
      :password     => 'abc',
      :host         => 's1.sat.com',
      :organization => organization['id']
    }
    _sat6_credential = create_obj(uri, data)

    unless v3_2?
      # These Credential types were removed from v3.2.

      # create cloud rackspace cred
      data = {
        :name         => 'hello_rax_cred',
        :kind         => 'rax',
        :username     => 'admin',
        :password     => 'abc',
        :organization => organization['id']
      }
      _rax_credential = create_obj(uri, data)

      # create cloud azure(Classic) cred
      data = {
        :name         => 'hello_azure_classic_cred',
        :kind         => 'azure',
        :username     => 'admin',
        :ssh_key_data => ssh_key_data,
        :organization => organization['id']
      }
      _azure_classic_credential = create_obj(uri, data)
    end

    # create inventory
    uri = '/api/v2/inventories/'
    data = {
      :name         => 'hello_inventory',
      :description  => 'inventory for miq spec tests',
      :organization => organization['id']
    }
    inventory = create_obj(uri, data)
    @tower_data[:items][data[:name]] = { :id => inventory['id'] }

    # create a host
    uri = '/api/v2/hosts/'
    data = {
      :name        => 'hello_vm',
      :instance_id => '4233080d-7467-de61-76c9-c8307b6e4830',
      :inventory   => inventory['id']
    }
    host = create_obj(uri, data)
    @tower_data[:items][data[:name]] = { :id => host['id'] }

    # create a project
    uri = '/api/v2/projects/'
    data = {
      :name         => 'hello_repo',
      :scm_url      => 'https://github.com/jameswnl/ansible-examples',
      :scm_type     => 'git',
      :credential   => scm_credential['id'],
      :organization => organization['id']
    }
    hello_project = create_obj(uri, data)
    @tower_data[:items][data[:name]] = hello_project.slice('id', 'status').symbolize_keys

    # Wait for hello_project update to finish, it is necessary for creating a template
    wait_for_project_update(hello_project)

    # Wait until there is a update job for "hello_repo".
    uri = nil
    project = try_get_obj_until(hello_project['url']) do |body|
      uri = body['related']['last_update']
      uri.present?
    end

    # Wait until the "hello_repo" update finishes.
    last_update = try_get_obj_until(uri) do |body|
      raise "\"#{data[:name]}\" cloning failed." if body['failed']
      body['finished'].present?
    end

    @tower_data[:items][data[:name]][:status] = last_update['status']
    @tower_data[:items][data[:name]][:last_updated] = Time.parse(last_update['finished']).utc
    @tower_data[:items][data[:name]][:playbooks] = get_obj(project['related']['playbooks'])

    # create a job_template
    uri = '/api/v2/job_templates/'
    data = {
      :name               => 'hello_template',
      :description        => 'test job',
      :job_type           => 'run',
      :project            => hello_project['id'],
      :playbook           => 'hello_world.yml',
      :credential         => machine_credential['id'],
      :cloud_credential   => aws_credential['id'],
      :network_credential => network_credential['id'],
      :inventory          => inventory['id'],
      :organization       => organization['id']
    }
    template = create_obj(uri, data)
    @tower_data[:items][data[:name]] = { :id => template['id'] }

    # create a job_template with survey spec
    uri = '/api/v2/job_templates/'
    data = {
      :name           => 'hello_template_with_survey',
      :description    => 'test job with survey spec',
      :job_type       => 'run',
      :project        => hello_project['id'],
      :playbook       => 'hello_world.yml',
      :credential     => machine_credential['id'],
      :inventory      => inventory['id'],
      :survey_enabled => true,
      :organization   => organization['id']
    }
    template = create_obj(uri, data)
    @tower_data[:items][data[:name]] = { :id => template['id'] }

    # create survey spec
    uri = "/api/v2/job_templates/#{template['id']}/survey_spec/"
    data = {
      :name        => 'Simple Survey',
      :description => 'Description of the simple survey',
      :spec        => [{
        :type                 => 'text',
        :question_name        => 'example question',
        :question_description => 'What is your favorite color?',
        :variable             => 'favorite_color',
        :required             => false,
        :default              => 'blue'
      }]
    }
    @conn.post(uri, data)

    # create workflow job template
    uri = '/api/v2/workflow_job_templates/'
    data = {
      :name         => 'hello_workflow',
      :description  => 'test workflow',
      :inventory    => inventory['id'],
      :organization => organization['id']
    }
    workflow_template = create_obj(uri, data)
    @tower_data[:items][data[:name]] = { :id => workflow_template['id'] }

    # Create a project with failed update.
    uri = '/api/v2/projects/'
    data = {
      :name         => 'failed_repo',
      :scm_url      => 'https://github.com/jameswnl/ansible-examplez',
      :scm_type     => 'git',
      :credential   => scm_credential['id'],
      :organization => organization['id']
    }
    create_obj(uri, data)

    # Create a project without an update job.
    uri = '/api/v2/projects/'
    data = {
      :name         => 'jobless_repo',
      :scm_url      => 'https://github.com/jameswnl/ansible-examples',
      :scm_type     => 'git',
      :credential   => scm_credential['id'],
      :organization => organization['id']
    }
    jobless_project = create_obj(uri, data)

    last_update = wait_for_project_update(jobless_project)
    @conn.delete(last_update['url'])

    # Create and remove project - record an collect an ID of missing entity
    uri = '/api/v2/projects/'
    data = {
      :name         => 'nonexistent_repo',
      :scm_url      => 'https://github.com/jameswnl/ansible-examples',
      :scm_type     => 'git',
      :credential   => scm_credential['id'],
      :organization => organization['id']
    }
    nonexistent_project = create_obj(uri, data)
    @tower_data[:items][data[:name]] = { :id => nonexistent_project['id'] }

    sleep(DEL_SLEEP)

    del_obj(uri, data[:name])

    self
  end

  def counts
    # Watched record types
    record_types = {
      :job_templates          => :configuration_script,
      :workflow_job_templates => :configuration_script,
      :projects               => :configuration_script_source,
      :hosts                  => :configured_system,
      :inventories            => :inventory_group,
      :credentials            => :credential,
      :playbooks              => :configuration_script_payload
    }

    # Collect total counts for various object types
    @tower_data[:total_counts] = {}
    record_types.except(:playbooks).each_key do |tower_name|
      count = get_obj("/api/v2/#{tower_name}/")['count']
      @tower_data[:total_counts][tower_name] = count
    end

    # Collect counts of playbooks (total and per project)
    playbook_counts_per_project = {}
    watched_projects = %w(hello_repo)
    @tower_data[:total_counts][:playbooks] = 0

    uri = '/api/v2/projects/'
    while uri
      response = get_obj(uri)
      uri = response['next']
      response['results'].each do |result|
        playbook_count = get_obj(result['related']['playbooks']).count

        playbook_counts_per_project[result['name']] = playbook_count if watched_projects.include?(result['name'])
        @tower_data[:total_counts][:playbooks] += playbook_count
      end
    end

    # Report the counts
    puts "=== Object counts ==="
    record_types.each_pair do |tower_name, miq_name|
      label = "#{miq_name} (#{tower_name})"
      puts "#{label.ljust(60)} #{@tower_data[:total_counts][tower_name]}"
    end

    playbook_counts_per_project.each_pair do |project, count|
      label = "    #{project}"
      puts "#{label.ljust(60)} #{count}"
    end

    self
  end
end
