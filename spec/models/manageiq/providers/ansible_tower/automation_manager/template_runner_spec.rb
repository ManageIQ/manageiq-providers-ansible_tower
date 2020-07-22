describe ManageIQ::Providers::AnsibleTower::AutomationManager::TemplateRunner do
  let(:manager_with_configuration_scripts) { FactoryBot.create(:automation_manager_ansible_tower, :configuration_script) }
  let(:template) { FactoryBot.create(:ansible_configuration_script, :manager => manager_with_configuration_scripts) }
  subject { ManageIQ::Providers::AnsibleTower::AutomationManager::TemplateRunner.create_job(options.merge(:ansible_template_id => template.id)) }

  describe '#start' do
    let(:options) { {} }

    it 'moves on to launch_ansible_tower_job' do
      expect(subject).to receive(:queue_signal).with(:launch_ansible_tower_job, :deliver_on => nil, :priority => nil)
      subject.start
    end
  end

  describe '#current_job_timeout' do
    context 'timeout set in options' do
      let(:options) { {:execution_ttl => 50} }

      it 'uses customized timeout value' do
        expect(subject.current_job_timeout).to eq(3000)
      end
    end

    context 'timeout not set in options' do
      let(:options) { {} }

      it 'uses default timeout value' do
        expect(subject.current_job_timeout).to eq(described_class::DEFAULT_EXECUTION_TTL * 60)
      end
    end

    context 'timeout is blank in options' do
      let(:options) { {:execution_ttl => ""} }

      it 'uses default timeout value' do
        expect(subject.current_job_timeout).to eq(described_class::DEFAULT_EXECUTION_TTL * 60)
      end
    end
  end

  describe '#launch_ansible_tower_job' do
    let(:options) { {:ansible_template_id => template.id} }

    context 'job template is ready' do
      it 'launches a job and moves on to poll_ansible_tower_job_status' do
        expect(ManageIQ::Providers::AnsibleTower::AutomationManager::Job).to receive(:create_job).and_return(double(:id => 'jb1'))
        expect(subject).to receive(:queue_signal).with(:poll_ansible_tower_job_status, kind_of(Integer), kind_of(Hash))
        subject.launch_ansible_tower_job
        expect(subject.options[:tower_job_id]).to eq('jb1')
      end
    end

    context 'error is raised' do
      it 'moves on to post_ansible_run' do
        allow(ManageIQ::Providers::AnsibleTower::AutomationManager::Job).to receive(:create_job).and_raise("can't complete the request")
        expect(subject).to receive(:signal).with(:post_ansible_run, "can't complete the request", "error")
        subject.launch_ansible_tower_job
      end
    end
  end

  describe '#poll_ansible_tower_job_status' do
    let(:options) { {:tower_job_id => 'jb1'} }

    context 'tower job is still running' do
      before { allow(subject).to receive(:ansible_job).and_return(double(:raw_status => double(:completed? => false))) }

      it 'requeues for later poll' do
        expect(subject).to receive(:queue_signal).with(:poll_ansible_tower_job_status, 10, kind_of(Hash))
        subject.poll_ansible_tower_job_status(10)
      end
    end

    context 'tower job finishes normally' do
      let(:ansible_job) { double(:raw_status => double(:completed? => true, :succeeded? => true), :refresh_ems => nil) }
      before { allow(subject).to receive(:ansible_job).and_return(ansible_job) }

      context 'always log output' do
        let(:options) { {:tower_job_id => 'jb1', :log_output => 'always'} }

        it 'gets ansible output and moves on to post_ansible_run with ok status' do
          expect(ansible_job).to receive(:raw_stdout)
          expect(subject).to receive(:signal).with(:post_ansible_run, kind_of(String), 'ok')
          subject.poll_ansible_tower_job_status(10)
        end
      end

      context 'log output on error' do
        let(:options) { {:tower_job_id => 'jb1', :log_output => 'on_error'} }

        it 'moves on to post_ansible_run with ok status' do
          expect(ansible_job).not_to receive(:raw_stdout)
          expect(subject).to receive(:signal).with(:post_ansible_run, kind_of(String), 'ok')
          subject.poll_ansible_tower_job_status(10)
        end
      end
    end

    context 'tower job fails' do
      let(:ansible_job) { double(:raw_status => double(:completed? => true, :succeeded? => false), :refresh_ems => nil) }
      before { allow(subject).to receive(:ansible_job).and_return(ansible_job) }

      context 'log output on error' do
        let(:options) { {:tower_job_id => 'jb1', :log_output => 'on_error'} }

        it 'gets ansible outputs and moves on to post_ansible_run with error status' do
          expect(ansible_job).to receive(:raw_stdout)
          expect(subject).to receive(:signal).with(:post_ansible_run, kind_of(String), 'error')
          subject.poll_ansible_tower_job_status(10)
        end
      end

      context 'never log output' do
        let(:options) { {:tower_job_id => 'jb1', :log_output => 'never'} }

        it 'moves on to post_ansible_run with error status' do
          expect(ansible_job).not_to receive(:raw_stdout)
          expect(subject).to receive(:signal).with(:post_ansible_run, kind_of(String), 'error')
          subject.poll_ansible_tower_job_status(10)
        end
      end
    end

    context 'error is raised' do
      before { allow(subject).to receive(:ansible_job).and_raise('internal error') }

      it 'moves on to post_ansible_run with error message' do
        expect(subject).to receive(:signal).with(:post_ansible_run, 'internal error', 'error')
        subject.poll_ansible_tower_job_status(10)
      end
    end
  end

  describe '#post_ansible_run' do
    let(:options) { {} }

    it 'template runs successfully' do
      subject.post_ansible_run("Template #{template.name} ran successfully", 'ok')
      expect(subject).to have_attributes(:state => 'finished', :status => 'ok')
    end

    it 'template runs with error' do
      subject.post_ansible_run('Ansible engine returned an error for the job', 'error')
      expect(subject).to have_attributes(:state => 'finished', :status => 'error')
    end
  end

  describe 'state transitions' do
    let(:options) { {} }

    %w[start launch_ansible_tower_job poll_ansible_tower_job_status post_ansible_run finish abort_job cancel error].each do |signal|
      shared_examples_for "allows #{signal} signal" do
        it signal.to_s do
          expect(subject).to receive(signal.to_sym)
          subject.signal(signal.to_sym)
        end
      end
    end

    %w[start launch_ansible_tower_job poll_ansible_tower_job_status post_ansible_run].each do |signal|
      shared_examples_for "does not allow #{signal} signal" do
        it signal.to_s do
          expect { subject.signal(signal.to_sym) }.to raise_error(RuntimeError, /#{signal} is not permitted at state #{subject.state}/)
        end
      end
    end

    context 'in waiting_to_start state' do
      before { subject.state = 'waiting_to_start' }

      it_behaves_like 'allows start signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'does not allow launch_ansible_tower_job signal'
      it_behaves_like 'does not allow poll_ansible_tower_job_status signal'
      it_behaves_like 'does not allow post_ansible_run signal'
    end

    context 'in running state' do
      before { subject.state = 'running' }

      it_behaves_like 'allows launch_ansible_tower_job signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'does not allow start signal'
      it_behaves_like 'does not allow poll_ansible_tower_job_status signal'
      it_behaves_like 'does not allow post_ansible_run signal'
    end

    context 'in ansible_job state' do
      before { subject.state = 'ansible_job' }

      it_behaves_like 'allows poll_ansible_tower_job_status signal'
      it_behaves_like 'allows post_ansible_run signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'does not allow start signal'
      it_behaves_like 'does not allow launch_ansible_tower_job signal'
    end

    context 'in ansible_done state' do
      before { subject.state = 'ansible_done' }
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'does not allow start signal'
      it_behaves_like 'does not allow launch_ansible_tower_job signal'
      it_behaves_like 'does not allow poll_ansible_tower_job_status signal'
      it_behaves_like 'does not allow post_ansible_run signal'
    end
  end
end
