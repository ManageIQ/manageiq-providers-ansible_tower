require 'ansible_tower_client'
require 'faraday'

describe ManageIQ::Providers::AnsibleTower::AutomationManager::WorkflowJob do
  let(:faraday_connection) { instance_double("Faraday::Connection", :post => post, :get => get) }
  let(:post) { instance_double("Faraday::Result", :body => {}.to_json) }
  let(:get)  { instance_double("Faraday::Result", :body => {'id' => 1}.to_json) }

  let(:connection) do
    double(:connection,
           :api => double(:api,
                          :workflow_jobs => double(:workflow_jobs, :find => the_raw_workflow_job),
                          :jobs          => double(:jobs, :find => the_raw_job)))
  end

  let(:manager)  { FactoryBot.create(:automation_manager_ansible_tower, :provider) }
  let(:mock_api) { AnsibleTowerClient::Api.new(faraday_connection) }

  let(:the_raw_workflow_job) do
    AnsibleTowerClient::WorkflowJob.new(
      mock_api,
      'id'         => '1',
      'related'    => {},
      'name'       => workflow_template.name,
      'status'     => 'Successful',
      'extra_vars' => {'param1' => 'val1'}.to_json,
      'started'    => Time.current,
      'finished'   => Time.current
    ).tap do |rjob|
      allow(rjob).to receive(:workflow_job_nodes).and_return([double('node', :job => the_raw_job)])
    end
  end

  let(:the_raw_job) { nil }
  let(:template) { FactoryBot.create(:ansible_configuration_script, :manager => manager) }
  let(:workflow_template) { FactoryBot.create(:configuration_workflow, :manager => manager) }
  subject { FactoryBot.create(:ansible_tower_workflow_job, :workflow_template => workflow_template, :ext_management_system => manager) }

  describe 'job operations' do
    describe ".create_job" do
      it 'creates a job' do
        expect(workflow_template).to receive(:run).and_return(the_raw_workflow_job)

        job = described_class.create_job(workflow_template, {})
        expect(job.class).to                 eq(described_class)
        expect(job.name).to                  eq(workflow_template.name)
        expect(job.ems_ref).to               eq(the_raw_workflow_job.id)
        expect(job.workflow_template).to     eq(workflow_template)
        expect(job.status).to                eq(the_raw_workflow_job.status)
        expect(job.ext_management_system).to eq(manager)
        expect(job.retireable?).to           be false
      end

      it 'catches errors from provider' do
        expect(workflow_template).to receive(:run).and_raise('bad request')

        expect do
          described_class.create_job(workflow_template, {})
        end.to raise_error(MiqException::MiqOrchestrationProvisionError)
      end

      context 'options have extra_vars' do
        let(:workflow_template) do
          FactoryBot.build(:configuration_workflow,
                            :manager     => manager,
                            :variables   => {'Var1' => 'v1', 'VAR2' => 'v2'},
                            :survey_spec => {'spec' => [{'default' => 'v3', 'variable' => 'var3', 'type' => 'text'}]})
        end

        it 'updates the extra_vars with original keys' do
          expect(workflow_template).to receive(:run).with(:extra_vars => {'Var1' => 'n1', 'VAR2' => 'n2', 'var3' => 'n3'}).and_return(the_raw_workflow_job)

          described_class.create_job(workflow_template, :extra_vars => {'var1' => 'n1', 'var2' => 'n2', 'VAR3' => 'n3'})
        end
      end
    end

    context "#refres_ems" do
      before do
        allow_any_instance_of(Provider).to receive_messages(:connect => connection)
      end

      let(:the_raw_job) do
        AnsibleTowerClient::Job.new(
          mock_api,
          'id'              => '1',
          'name'            => template.name,
          'status'          => 'Successful',
          'extra_vars'      => {'param1' => 'val1'}.to_json,
          'verbosity'       => 3,
          'started'         => Time.current,
          'finished'        => Time.current,
          'job_template_id' => template.manager_ref
        ).tap do |rjob|
          allow(rjob).to receive(:job_events).with(:event => 'playbook_on_play_start').and_return(the_raw_plays)
        end
      end

      let(:the_raw_plays) do
        [
          double('play1', :play => 'play1', :created => Time.current,     :failed => false, :id => 1),
          double('play2', :play => 'play2', :created => Time.current + 1, :failed => true,  :id => 2)
        ]
      end

      it 'syncs the job with the provider' do
        subject.refresh_ems
        expect(subject).to have_attributes(
          :ems_ref     => the_raw_workflow_job.id,
          :status      => the_raw_workflow_job.status,
          :start_time  => a_value_within(1.second).of(the_raw_workflow_job.started),
          :finish_time => a_value_within(1.second).of(the_raw_workflow_job.finished)
        )
        subject.reload
        expect(subject.ems_ref).to eq(the_raw_workflow_job.id)
        expect(subject.status).to  eq(the_raw_workflow_job.status)
        expect(subject.parameters.first).to have_attributes(:name => 'param1', :value => 'val1')
      end

      it 'catches errors from provider' do
        expect(connection.api.workflow_jobs).to receive(:find).and_raise('bad request')
        expect { subject.refresh_ems }.to raise_error(MiqException::MiqOrchestrationUpdateError)
      end

      it 'updates child jobs' do
        subject.refresh_ems
        expect(subject.jobs.size).to eq(1)
        child_job = subject.jobs.first
        expect(child_job.name).to                  eq(template.name)
        expect(child_job.ems_ref).to               eq(the_raw_job.id)
        expect(child_job.job_template).to          eq(template)
        expect(child_job.status).to                eq(the_raw_job.status)
        expect(child_job.ext_management_system).to eq(manager)
      end
    end

    describe '#retire_now' do
      it 'processes retire_now properly' do
        expect(subject).to receive(:finish_retirement).once
        subject.retire_now
      end
    end
  end
end
