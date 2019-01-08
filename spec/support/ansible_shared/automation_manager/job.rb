require 'ansible_tower_client'
require 'faraday'

shared_examples_for "ansible job" do
  let(:faraday_connection) { instance_double("Faraday::Connection", :post => post, :get => get) }
  let(:post) { instance_double("Faraday::Result", :body => {}.to_json) }
  let(:get)  { instance_double("Faraday::Result", :body => {'id' => 1}.to_json) }

  let(:connection) { double(:connection, :api => double(:api, :jobs => double(:jobs, :find => the_raw_job))) }

  let(:manager)  { FactoryBot.create(:automation_manager_ansible_tower, :provider) }
  let(:mock_api) { AnsibleTowerClient::Api.new(faraday_connection) }

  let(:machine_credential) { FactoryBot.create(:ansible_machine_credential, :manager_ref => '1', :resource => manager) }
  let(:cloud_credential)   { FactoryBot.create(:ansible_cloud_credential,   :manager_ref => '2', :resource => manager) }
  let(:network_credential) { FactoryBot.create(:ansible_network_credential, :manager_ref => '3', :resource => manager) }
  let(:vault_credential)   { FactoryBot.create(:ansible_vault_credential,   :manager_ref => '4', :resource => manager) }

  let(:the_raw_job) do
    AnsibleTowerClient::Job.new(
      mock_api,
      'id'                    => '1',
      'name'                  => template.name,
      'status'                => 'Successful',
      'extra_vars'            => {'param1' => 'val1'}.to_json,
      'verbosity'             => 3,
      'started'               => Time.current,
      'finished'              => Time.current,
      'credential_id'         => machine_credential.manager_ref,
      'vault_credential_id'   => vault_credential.manager_ref,
      'cloud_credential_id'   => cloud_credential.manager_ref,
      'network_credential_id' => network_credential.manager_ref
    ).tap do |rjob|
      allow(rjob).to receive(:stdout).with('html').and_return('<html><body>job stdout</body></html>')
      allow(rjob).to receive(:job_events).with(:event => 'playbook_on_play_start').and_return(the_raw_plays)
    end
  end

  let(:the_raw_plays) do
    [
      double('play1', :play => 'play1', :created => Time.current,     :failed => false, :id => 1),
      double('play2', :play => 'play2', :created => Time.current + 1, :failed => true,  :id => 2)
    ]
  end

  let(:template) { FactoryBot.create(:configuration_script, :manager => manager) }
  subject { FactoryBot.create(:ansible_tower_job, :job_template => template, :ext_management_system => manager) }

  describe 'job operations' do
    describe ".create_job" do
      context 'template is persisted' do
        it 'creates a job' do
          expect(template).to receive(:run).and_return(the_raw_job)

          job = described_class.create_job(template, {})
          expect(job.class).to                 eq(described_class)
          expect(job.name).to                  eq(template.name)
          expect(job.ems_ref).to               eq(the_raw_job.id)
          expect(job.job_template).to          eq(template)
          expect(job.status).to                eq(the_raw_job.status)
          expect(job.ext_management_system).to eq(manager)
          expect(job.retireable?).to           be false
        end
      end

      context 'template is temporary' do
        let(:template) { FactoryBot.build(:configuration_script, :manager => manager) }

        it 'creates a job' do
          expect(template).to receive(:run).and_return(the_raw_job)

          job = described_class.create_job(template, {})
          expect(job.job_template).to be_nil
        end
      end

      it 'catches errors from provider' do
        expect(template).to receive(:run).and_raise('bad request')

        expect do
          described_class.create_job(template, {})
        end.to raise_error(MiqException::MiqOrchestrationProvisionError)
      end

      context 'options have extra_vars' do
        let(:template) do
          FactoryBot.build(:configuration_script,
                            :manager     => manager,
                            :variables   => {'Var1' => 'v1', 'VAR2' => 'v2'},
                            :survey_spec => {'spec' => [{'default' => 'v3', 'variable' => 'var3', 'type' => 'text'}]})
        end

        it 'updates the extra_vars with original keys' do
          expect(template).to receive(:run).with(:extra_vars => {'Var1' => 'n1', 'VAR2' => 'n2', 'var3' => 'n3'}).and_return(the_raw_job)

          described_class.create_job(template, :extra_vars => {'var1' => 'n1', 'var2' => 'n2', 'VAR3' => 'n3'})
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
          :finish_time => a_value_within(1.second).of(the_raw_job.finished),
          :verbosity   => the_raw_job.verbosity
        )
        subject.reload
        expect(subject.ems_ref).to eq(the_raw_job.id)
        expect(subject.status).to  eq(the_raw_job.status)
        expect(subject.parameters.first).to have_attributes(:name => 'param1', :value => 'val1')
        expect(subject.authentications).to match_array([machine_credential, vault_credential, cloud_credential, network_credential])

        expect(subject.job_plays.first).to have_attributes(
          :start_time        => a_value_within(1.second).of(the_raw_plays.first.created),
          :finish_time       => a_value_within(1.second).of(the_raw_plays.last.created),
          :resource_status   => 'successful',
          :resource_category => 'job_play',
          :name              => 'play1'
        )
        expect(subject.job_plays.last).to have_attributes(
          :start_time        => a_value_within(1.second).of(the_raw_plays.last.created),
          :finish_time       => a_value_within(1.second).of(the_raw_job.finished),
          :resource_status   => 'failed',
          :resource_category => 'job_play',
          :name              => 'play2'
        )
      end

      it 'catches errors from provider' do
        expect(connection.api.jobs).to receive(:find).and_raise('bad request')
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

  describe 'job status' do
    before do
      allow_any_instance_of(Provider).to receive_messages(:connect => connection)
    end

    context '#raw_status and #raw_exists' do
      it 'gets the stack status' do
        rstatus = subject.raw_status
        expect(rstatus).to have_attributes(:status => 'Successful', :reason => nil)

        expect(subject.raw_exists?).to be_truthy
      end

      it 'detects job not exist' do
        expect(connection.api.jobs).to receive(:find).twice.and_raise(AnsibleTowerClient::ResourceNotFoundError.new(nil))
        expect { subject.raw_status }.to raise_error(MiqException::MiqOrchestrationStackNotExistError)

        expect(subject.raw_exists?).to be_falsey
      end

      it 'catches errors from provider' do
        expect(connection.api.jobs).to receive(:find).twice.and_raise("bad happened")
        expect { subject.raw_status }.to raise_error(MiqException::MiqOrchestrationStatusError)

        expect { subject.raw_exists? }.to raise_error(MiqException::MiqOrchestrationStatusError)
      end
    end
  end

  describe '#raw_stdout' do
    before do
      allow_any_instance_of(Provider).to receive_messages(:connect => connection)
    end

    it 'gets the standard output of the job' do
      expect(subject.raw_stdout('html')).to eq('<html><body>job stdout</body></html>')
    end

    it 'catches errors from provider' do
      expect(connection.api.jobs).to receive(:find).and_raise("bad happened")
      expect { subject.raw_stdout('html') }.to raise_error(MiqException::MiqOrchestrationStatusError)
    end
  end

  describe '#raw_stdout_via_worker' do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      allow(described_class).to receive(:find).and_return(job)

      allow(MiqTask).to receive(:wait_for_taskid) do
        request = MiqQueue.find_by(:class_name => described_class.name)
        request.update_attributes(:state => MiqQueue::STATE_DEQUEUE)
        request.delivered(*request.deliver)
      end
    end

    it 'gets stdout from the job' do
      expect(job).to receive(:raw_stdout).and_return('A stdout from the job')
      taskid = job.raw_stdout_via_worker('user')
      MiqTask.wait_for_taskid(taskid)
      expect(MiqTask.find(taskid)).to have_attributes(
        :task_results => 'A stdout from the job',
        :status       => 'Ok'
      )
    end

    it 'returns the error message' do
      expect(job).to receive(:raw_stdout).and_throw('Failed to get stdout from the job')
      taskid = job.raw_stdout_via_worker('user')
      MiqTask.wait_for_taskid(taskid)
      expect(MiqTask.find(taskid).message).to include('Failed to get stdout from the job')
      expect(MiqTask.find(taskid).status).to eq('Error')
    end
  end
end
