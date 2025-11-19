describe ManageIQ::Providers::AnsibleTower::AutomationManager::Provision do
  require "ansible_tower_client"

  let(:admin)        { FactoryBot.create(:user_admin) }
  let(:zone)         { EvmSpecHelper.local_miq_server.zone }
  let(:ems)          { FactoryBot.create(:automation_manager_ansible_tower, :zone => zone).tap { |ems| ems.authentications << FactoryBot.create(:authentication, :status => "Valid", :auth_key => "abcd") } }
  let(:job_template) { FactoryBot.create(:ansible_configuration_script, :manager => ems) }
  let(:miq_request)  { FactoryBot.create(:miq_provision_request, :requester => admin, :source => job_template) }
  let(:options)      { {:source => [job_template.id, job_template.name]} }
  let(:new_stack)    { FactoryBot.create(:ansible_tower_job, :ext_management_system => ems, :status => stack_status) }
  let(:stack_status) { "pending" }
  let(:phase)        { nil }
  let(:subject) do
    FactoryBot.create(
      :miq_provision_awx,
      :userid       => admin.userid,
      :miq_request  => miq_request,
      :source       => job_template,
      :request_type => 'template',
      :state        => 'pending',
      :status       => 'Ok',
      :options      => options,
      :phase        => phase
    )
  end

  it ".my_role" do
    expect(subject.my_role).to eq("ems_operations")
  end

  it ".my_queue_name" do
    expect(subject.my_queue_name).to eq(ems.queue_name_for_ems_operations)
  end

  describe ".run_provision" do
    before do
      allow(described_class.module_parent::Job).to receive(:create_stack).with(job_template).and_return(new_stack)
    end

    it "calls create_stack" do
      expect(described_class.module_parent::Job).to receive(:create_stack)

      subject.run_provision
    end

    it "sets stack_id" do
      subject.run_provision

      expect(subject.reload.phase_context).to include(:stack_id => new_stack.id)
    end

    it "queues check_provisioned" do
      subject.instance_variable_set(:@stack, new_stack)
      allow(new_stack).to receive(:raw_status).and_return(new_stack.class.status_class.new(stack_status, nil))

      subject.run_provision

      expect(subject.reload.phase).to eq("check_provisioned")
    end

    context "when create_stack fails" do
      before do
        expect(described_class.module_parent::Job).to receive(:create_stack).and_raise
      end

      it "marks the job as failed" do
        subject.run_provision

        expect(subject.reload).to have_attributes(:state => "finished", :status => "Error")
      end
    end
  end

  describe "check_provisioned" do
    let(:phase) { "check_provisioned" }

    before do
      allow(new_stack).to receive(:raw_status).and_return(new_stack.class.status_class.new(stack_status, nil))
      subject.instance_variable_set(:@stack, new_stack)
      subject.phase_context[:stack_id] = new_stack.id
    end

    context "when the plan is still running" do
      let(:stack_status) { "running" }

      it "requeues check_provisioned" do
        subject.check_provisioned

        expect(subject.reload).to have_attributes(
          :phase  => "check_provisioned",
          :state  => "pending",
          :status => "Ok"
        )
      end
    end

    context "when the plan is finished" do
      let(:stack_status) { "successful" }

      it "finishes the job" do
        subject.check_provisioned

        expect(subject.reload).to have_attributes(
          :phase  => "finish",
          :state  => "finished",
          :status => "Ok"
        )
      end
    end

    context "when the plan is errored" do
      let(:stack_status) { "failed" }

      it "finishes the job" do
        subject.phase_context[:stack_id] = new_stack.id
        subject.check_provisioned

        expect(subject.reload).to have_attributes(
          :phase  => "finish",
          :state  => "finished",
          :status => "Error"
        )
      end
    end
  end
end
