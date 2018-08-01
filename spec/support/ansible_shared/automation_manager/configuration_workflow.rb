require 'ansible_tower_client'
require 'faraday'

shared_examples_for "ansible configuration_workflow" do
  let(:api)                   { double(:api, :workflow_job_templates => double(:workflow_job_templates)) }
  let(:connection)            { double(:connection, :api => api) }
  let(:job)                   { AnsibleTowerClient::WorkflowJob.new(connection.api, "id" => 1) }
  let(:workflow_job_template) { AnsibleTowerClient::WorkflowJobTemplate.new(connection.api, "limit" => "", "id" => 1, "url" => "api/workflow_job_templates/1/", "name" => "template", "description" => "description", "extra_vars" => {:instance_ids => ['i-3434']}) }
  let(:manager)               { manager_with_configuration_workflows }
  context "#run" do
    before do
      allow_any_instance_of(Provider).to receive_messages(:connect => connection)
      allow(api.workflow_job_templates).to receive(:find) { workflow_job_template }
    end

    it "launches the referenced ansible workflow job template" do
      expect(workflow_job_template).to receive(:launch).with(:extra_vars => "{\"instance_ids\":[\"i-3434\"]}").and_return(job)
      expect(manager.configuration_scripts.first.run).to be_a AnsibleTowerClient::WorkflowJob
    end

    it "accepts different variables to launch a job template against" do
      added_extras = {:extra_vars => {:some_key => :some_value}}
      expect(workflow_job_template).to receive(:launch).with(:extra_vars=>"{\"instance_ids\":[\"i-3434\"],\"some_key\":\"some_value\"}").and_return(job)
      expect(manager.configuration_scripts.first.run(added_extras)).to be_a AnsibleTowerClient::WorkflowJob
    end
  end

  context "#merge_extra_vars" do
    it "merges internal and external hashes to send out to the tower gem" do
      config_workflow = manager.configuration_scripts.first
      external = {:some_key => :some_value}
      internal = config_workflow.variables
      expect(internal).to be_a Hash
      expect(config_workflow.merge_extra_vars(external)).to eq(:extra_vars => "{\"instance_ids\":[\"i-3434\"],\"some_key\":\"some_value\"}")
    end

    it "merges an internal hash and an empty hash to send out to the tower gem" do
      config_workflow = manager.configuration_scripts.first
      external = nil
      expect(config_workflow.merge_extra_vars(external)).to eq(:extra_vars => "{\"instance_ids\":[\"i-3434\"]}")
    end

    it "merges an empty internal hash and a hash to send out to the tower gem" do
      external = {:some_key => :some_value}
      internal = {}
      config_workflow = manager.configuration_scripts.first
      config_workflow.variables = internal
      expect(config_workflow.merge_extra_vars(external)).to eq(:extra_vars => "{\"some_key\":\"some_value\"}")
    end

    it "merges all empty arguments to send out to the tower gem" do
      external = nil
      internal = {}
      config_workflow = manager.configuration_scripts.first
      config_workflow.variables = internal
      expect(config_workflow.merge_extra_vars(external)).to eq(:extra_vars => "{}")
    end
  end
end
