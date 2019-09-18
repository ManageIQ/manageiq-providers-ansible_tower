require 'ansible_tower_client'
require 'faraday'

describe ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationWorkflow do
  let(:provider_with_authentication)         { FactoryBot.create(:provider_ansible_tower, :with_authentication) }
  let(:manager_with_authentication)          { provider_with_authentication.managers.first }

  let(:api)                   { double(:api, :workflow_job_templates => double(:workflow_job_templates)) }
  let(:connection)            { double(:connection, :api => api) }
  let(:job)                   { AnsibleTowerClient::WorkflowJob.new(connection.api, "id" => 1) }
  let(:workflow_job_template) { AnsibleTowerClient::WorkflowJobTemplate.new(connection.api, "limit" => "", "id" => 1, "url" => "api/workflow_job_templates/1/", "name" => "template", "description" => "description", "extra_vars" => {:instance_ids => ['i-3434']}) }
  let(:manager)               { FactoryBot.create(:automation_manager_ansible_tower, :provider, :configuration_workflow) }
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

  it 'designates orchestration stack type' do
    expect(described_class.stack_type).to eq('WorkflowJob')
  end

  describe '#run_with_miq_job' do
    it 'delegates request to template runner' do
      double_return = double(:signal => nil, :miq_task => double(:id => 'tid'))
      expect(ManageIQ::Providers::AnsibleTower::AutomationManager::TemplateRunner)
        .to receive(:create_job).with(hash_including(:ansible_template_id => subject.id, :userid => 'system')).and_return(double_return)
      expect(subject.run_with_miq_job({})).to eq('tid')
    end
  end
end
