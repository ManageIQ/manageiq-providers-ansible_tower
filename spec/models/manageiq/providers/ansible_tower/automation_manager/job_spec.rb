describe ManageIQ::Providers::AnsibleTower::AutomationManager::Job do
  let(:job) { FactoryGirl.create(:ansible_tower_job) }

  it_behaves_like 'ansible job'

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
