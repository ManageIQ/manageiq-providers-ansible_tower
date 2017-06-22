#!/usr/bin/env ruby

# This script is to create a set of objects in Tower.
# The objects will be captured in a vcr cassette and will be used for refresh spec tests.
# If we need to update the cassette, we can update/rerun this script to modify the objects
# and so spec expectations can be updated (hopefully) easily

require "faraday"
require 'faraday_middleware'

def create_obj(conn, uri, data)
  del_obj(conn, uri, data['name'])
  obj = JSON.parse(conn.post(uri, data).body)
  puts "Created name=#{obj['name']}, manager_ref/ems_ref= #{obj['id']}, url=#{obj['url']}"
  obj
end

def del_obj(conn, uri, match_name)
  data = JSON.parse(conn.get(uri).body)
  data['results'].each do |item|
    next if item['name'] != match_name
    puts "   deleting old #{item['name']}: #{item['url']}"
    resp = conn.delete(item['url'])
    sleep(20) # without sleep, sometimes subsequent create will return 400. Seems the deletion has some delay in Tower
    resp
  end
  del_obj(conn, data['next'], match_name) if data['next']
end

def create_dataset(tower_host, id, password)
  conn = Faraday.new(tower_host, :ssl => {:verify => false}) do |c|
    c.use(FaradayMiddleware::EncodeJson)
    c.use(FaradayMiddleware::FollowRedirects, :limit => 3, :standards_compliant => true)
    c.use Faraday::Response::RaiseError
    c.adapter(Faraday.default_adapter)
    c.basic_auth(id, password)
  end

  # create test organization
  uri = '/api/v1/organizations/'
  data = {"name" => 'spec_test_org', "description" => "for miq spec tests"}
  organization = create_obj(conn, uri, data)

  # create scm cred
  uri = '/api/v1/credentials/'
  data = {"name" => "hello_scm_cred", "kind" => "scm", "username" => "admin", "password" => "abc", "organization" => organization['id']}
  scm_credential = create_obj(conn, uri, data)

  # create machine cred
  data = {"name" => "hello_machine_cred", "kind" => "ssh", "username" => "admin", "password" => "abc", "organization" => organization['id']}
  machine_credential = create_obj(conn, uri, data)

  # create cloud aws cred
  data = {"name" => "hello_aws_cred", "kind" => "aws", "username" => "ABC", "password" => "abc", "organization" => organization['id']}
  aws_credential = create_obj(conn, uri, data)

  # create network cred
  data = {"name" => "hello_network_cred", "kind" => "net", "username" => "admin", "password" => "abc", "organization" => organization['id']}
  network_credential = create_obj(conn, uri, data)

  # create inventory
  uri = '/api/v1/inventories/'
  data = {"name" => "hello_inventory", "description" => "inventory for miq spec tests", "organization" => organization['id']}
  inventory = create_obj(conn, uri, data)

  # create a host
  uri = '/api/v1/hosts/'
  data = {"name" => "hello_vm", "instance_id" => "4233080d-7467-de61-76c9-c8307b6e4830", "inventory" => inventory['id']}
  create_obj(conn, uri, data)

  # create a project
  uri = '/api/v1/projects/'
  data = {"name" => 'hello_repo', "scm_url" => "https://github.com/jameswnl/ansible-examples", "scm_type" => "git", "credential" => scm_credential['id'], "organization" => organization['id']}
  project = create_obj(conn, uri, data)

  # create a job_template
  uri = '/api/v1/job_templates/'
  data = {"name" => 'hello_template', "description" => "test job", "job_type" => "run", "project" => project['id'], "playbook" => "hello_world.yml", "credential" => machine_credential['id'], "cloud_credential" => aws_credential['id'], "network_credential" => network_credential['id'], "inventory" => inventory['id'], "organization" => organization['id']}
  create_obj(conn, uri, data)

  # create a job_template with survey spec
  uri = '/api/v1/job_templates/'
  data = {"name" => "hello_template_with_survey", "description" => "test job with survey spec", "job_type" => "run", "project" => project['id'], "playbook" => "hello_world.yml", "credential" => machine_credential['id'], "inventory" => inventory['id'], "survey_enabled" => true, "organization" => organization['id']}
  template = create_obj(conn, uri, data)
  # create survey spec
  uri = "/api/v1/job_templates/#{template['id']}/survey_spec/"
  data = {"name" => "Simple Survey", "description" => "Description of the simple survey", "spec" => [{"type" => "text", "question_name" => "example question", "question_description" => "What is your favorite color?", "variable" => "favorite_color", "required" => false, "default" => "blue"}]}
  conn.post(uri, data).body
  puts "created #{template['url']} survey_spec"
end

tower_host = ENV['TOWER_URL'] || "https://dev-ansible-tower3.example.com/api/v1/"
id = ENV['TOWER_USER'] || 'testuser'
password = ENV['TOWER_PASSWORD'] || 'secret'

create_dataset(tower_host, id, password)
