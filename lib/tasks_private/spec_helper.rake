namespace :spec do
  desc "Populate expected Tower objects for casssettes and spec tests"
  task :populate_tower do
    tower_host = ENV['TOWER_URL'] || "https://dev-ansible-tower3.example.com/api/v1/"
    id = ENV['TOWER_USER'] || 'testuser'
    password = ENV['TOWER_PASSWORD'] || 'secret'
    PopulateTower.new(tower_host, id, password).create_dataset.counts
  end

  desc "Get counts of various Tower objects"
  task :tower_counts do
    tower_host = ENV['TOWER_URL'] || "https://dev-ansible-tower3.example.com/api/v1/"
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
  # Created name=hello_aws_cred              manager_ref/ems_ref= 138       url=/api/v1/credentials/138/
  # Created name=hello_network_cred          manager_ref/ems_ref= 139       url=/api/v1/credentials/139/
  # Created name=hello_inventory             manager_ref/ems_ref= 110       url=/api/v1/inventories/110/
  # Created name=hello_vm                    manager_ref/ems_ref= 249       url=/api/v1/hosts/249/
  # Created name=hello_repo                  manager_ref/ems_ref= 591       url=/api/v1/projects/591/
  #   deleting old hello_template: /api/v1/job_templates/589/
  # Created name=hello_template              manager_ref/ems_ref= 592       url=/api/v1/job_templates/592/
  #   deleting old hello_template_with_survey: /api/v1/job_templates/590/
  # Created name=hello_template_with_survey  manager_ref/ems_ref= 593       url=/api/v1/job_templates/593/
  # created /api/v1/job_templates/593/ survey_spec
  # === Object counts ===
  # configuration_script           (job_templates)     : 120
  # configuration_script_source    (projects)          : 32
  # configured_system              (hosts)             : 133
  # inventory_group                (inventories)       : 29
  # credential                     (credentials)       : 47
  #

  require "faraday"
  require 'faraday_middleware'

  def initialize(tower_host, id, password)
    @conn = Faraday.new(tower_host, :ssl => {:verify => false}) do |c|
      c.use(FaradayMiddleware::EncodeJson)
      c.use(FaradayMiddleware::FollowRedirects, :limit => 3, :standards_compliant => true)
      c.use Faraday::Response::RaiseError
      c.adapter(Faraday.default_adapter)
      c.basic_auth(id, password)
    end
  end

  def create_obj(uri, data)
    del_obj(uri, data['name'])
    obj = JSON.parse(@conn.post(uri, data).body)
    puts "%s %s %s" % ["Created name=#{obj['name']}".ljust(40), "manager_ref/ems_ref= #{obj['id']}".ljust(30), "url=#{obj['url']}".ljust(10)]
    obj
  end

  def del_obj(uri, match_name)
    data = JSON.parse(@conn.get(uri).body)
    data['results'].each do |item|
      next if item['name'] != match_name
      puts "   deleting old #{item['name']}: #{item['url']}"
      resp = @conn.delete(item['url'])
      sleep(20) # without sleep, sometimes subsequent create will return 400. Seems the deletion has some delay in Tower
      resp
    end
    del_obj(data['next'], match_name) if data['next']
  end

  def create_dataset
    puts "=== Re-creating Tower objects ==="
    # create test organization
    uri = '/api/v1/organizations/'
    data = {"name" => 'spec_test_org', "description" => "for miq spec tests"}
    organization = create_obj(uri, data)

    # create scm cred
    uri = '/api/v1/credentials/'
    data = {"name" => "hello_scm_cred", "kind" => "scm", "username" => "admin", "password" => "abc", "organization" => organization['id']}
    scm_credential = create_obj(uri, data)

    # create machine cred
    data = {"name" => "hello_machine_cred", "kind" => "ssh", "username" => "admin", "password" => "abc", "organization" => organization['id']}
    machine_credential = create_obj(uri, data)

    # create cloud aws cred
    data = {"name" => "hello_aws_cred", "kind" => "aws", "username" => "ABC", "password" => "abc", "organization" => organization['id']}
    aws_credential = create_obj(uri, data)

    # create network cred
    data = {"name" => "hello_network_cred", "kind" => "net", "username" => "admin", "password" => "abc", "organization" => organization['id']}
    network_credential = create_obj(uri, data)

    # create inventory
    uri = '/api/v1/inventories/'
    data = {"name" => "hello_inventory", "description" => "inventory for miq spec tests", "organization" => organization['id']}
    inventory = create_obj(uri, data)

    # create a host
    uri = '/api/v1/hosts/'
    data = {"name" => "hello_vm", "instance_id" => "4233080d-7467-de61-76c9-c8307b6e4830", "inventory" => inventory['id']}
    create_obj(uri, data)

    # create a project
    uri = '/api/v1/projects/'
    data = {"name" => 'hello_repo', "scm_url" => "https://github.com/jameswnl/ansible-examples", "scm_type" => "git", "credential" => scm_credential['id'], "organization" => organization['id']}
    project = create_obj(uri, data)

    # create a job_template
    uri = '/api/v1/job_templates/'
    data = {"name" => 'hello_template', "description" => "test job", "job_type" => "run", "project" => project['id'], "playbook" => "hello_world.yml", "credential" => machine_credential['id'], "cloud_credential" => aws_credential['id'], "network_credential" => network_credential['id'], "inventory" => inventory['id'], "organization" => organization['id']}
    create_obj(uri, data)

    # create a job_template with survey spec
    uri = '/api/v1/job_templates/'
    data = {"name" => "hello_template_with_survey", "description" => "test job with survey spec", "job_type" => "run", "project" => project['id'], "playbook" => "hello_world.yml", "credential" => machine_credential['id'], "inventory" => inventory['id'], "survey_enabled" => true, "organization" => organization['id']}
    template = create_obj(uri, data)
    # create survey spec
    uri = "/api/v1/job_templates/#{template['id']}/survey_spec/"
    data = {"name" => "Simple Survey", "description" => "Description of the simple survey", "spec" => [{"type" => "text", "question_name" => "example question", "question_description" => "What is your favorite color?", "variable" => "favorite_color", "required" => false, "default" => "blue"}]}
    @conn.post(uri, data).body
    puts "created #{template['url']} survey_spec"
    self
  end

  def counts
    puts "=== Object counts ==="
    targets = {
      'configuration_script'        => 'job_templates',
      'configuration_script_source' => 'projects',
      'configured_system'           => 'hosts',
      'inventory_group'             => 'inventories',
      'credential'                  => 'credentials'
    }
    targets.each do |miq_name, tower_name|
      count = JSON.parse(@conn.get("/api/v1/#{tower_name}/").body)['count']
      puts("%s %s: %s" % [miq_name.ljust(30), "(#{tower_name})".ljust(20), count])
    end
    self
  end
end
