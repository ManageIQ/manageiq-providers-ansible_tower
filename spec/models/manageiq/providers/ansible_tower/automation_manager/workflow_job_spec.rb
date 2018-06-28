require 'ansible_tower_client'
require 'faraday'

describe ManageIQ::Providers::AnsibleTower::AutomationManager::WorkflowJob do
  let(:faraday_connection) { instance_double("Faraday::Connection", :post => post, :get => get) }
  let(:post) { instance_double("Faraday::Result", :body => {}.to_json) }
  let(:get)  { instance_double("Faraday::Result", :body => {'id' => 1}.to_json) }

  let(:connection) { double(:connection, :api => double(:api, :workflow_jobs => double(:workflow_jobs, :find => the_raw_job))) }

  let(:manager)  { FactoryGirl.create(:automation_manager_ansible_tower, :provider) }
  let(:mock_api) { AnsibleTowerClient::Api.new(faraday_connection, 1) }

  let(:the_raw_job) do
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
      allow(rjob).to receive(:workflow_nodes).and_return([double('node')])
    end
  end

  let(:workflow_template) { FactoryGirl.create(:configuration_workflow, :manager => manager) }
  subject { FactoryGirl.create(:ansible_tower_workflow_job, :workflow_template => workflow_template, :ext_management_system => manager) }

  describe 'job operations' do
    describe ".create_job" do
      it 'creates a job' do
        expect(workflow_template).to receive(:run).and_return(the_raw_job)

        job = described_class.create_job(workflow_template, {})
        expect(job.class).to                 eq(described_class)
        expect(job.name).to                  eq(workflow_template.name)
        expect(job.ems_ref).to               eq(the_raw_job.id)
        expect(job.workflow_template).to     eq(workflow_template)
        expect(job.status).to                eq(the_raw_job.status)
        expect(job.ext_management_system).to eq(manager)
      end

      it 'catches errors from provider' do
        expect(workflow_template).to receive(:run).and_raise('bad request')

        expect do
          described_class.create_job(workflow_template, {})
        end.to raise_error(MiqException::MiqOrchestrationProvisionError)
      end

      context 'options have extra_vars' do
        let(:workflow_template) do
          FactoryGirl.build(:configuration_workflow,
                            :manager     => manager,
                            :variables   => {'Var1' => 'v1', 'VAR2' => 'v2'},
                            :survey_spec => {'spec' => [{'default' => 'v3', 'variable' => 'var3', 'type' => 'text'}]})
        end

        it 'updates the extra_vars with original keys' do
          expect(workflow_template).to receive(:run).with(:extra_vars => {'Var1' => 'n1', 'VAR2' => 'n2', 'var3' => 'n3'}).and_return(the_raw_job)

          described_class.create_job(workflow_template, :extra_vars => {'var1' => 'n1', 'var2' => 'n2', 'VAR3' => 'n3'})
        end
      end
    end

    context "#refres_ems" do
      before do
        allow_any_instance_of(Provider).to receive_messages(:connect => connection)
      end

      it 'syncs the job with the provider' do
        subject.refresh_ems
        expect(subject).to have_attributes(
          :ems_ref     => the_raw_job.id,
          :status      => the_raw_job.status,
          :start_time  => a_value_within(1.second).of(the_raw_job.started),
          :finish_time => a_value_within(1.second).of(the_raw_job.finished)
        )
        subject.reload
        expect(subject.ems_ref).to eq(the_raw_job.id)
        expect(subject.status).to  eq(the_raw_job.status)
        expect(subject.parameters.first).to have_attributes(:name => 'param1', :value => 'val1')
      end

      it 'catches errors from provider' do
        expect(connection.api.workflow_jobs).to receive(:find).and_raise('bad request')
        expect { subject.refresh_ems }.to raise_error(MiqException::MiqOrchestrationUpdateError)
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
