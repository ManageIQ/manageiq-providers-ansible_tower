require 'ansible_tower_client'

shared_examples_for "ansible configuration_script_source" do
  let(:finished_task) { FactoryBot.create(:miq_task, :state => "Finished") }
  let(:atc)           { double("AnsibleTowerClient::Connection", :api => api) }
  let(:api)           { double("AnsibleTowerClient::Api", :projects => projects) }
  let(:credential)    { FactoryBot.create(:ansible_scm_credential, :manager_ref => '1') }

  context "create through API" do
    let(:projects) { double("AnsibleTowerClient::Collection", :create! => project) }
    let(:project)  { AnsibleTowerClient::Project.new(nil, project_json) }

    let(:project_json) do
      params.merge(
        :id        => 10,
        "scm_type" => "git",
        "scm_url"  => "https://github.com/ansible/ansible-tower-samples"
      ).stringify_keys.to_json
    end

    let(:params) do
      {
        :description => "Description",
        :name        => "My Project",
        :related     => {}
      }
    end

    let(:expected_notify_creation) { expected_notify_action('creation') }
    let(:expected_notify_refresh_in_provider) { expected_notify_action('refresh in provider') }

    it ".create_in_provider to succeed and send creation notification" do
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      store_new_project(project, manager)
      expect(described_class).to receive(:refresh_in_provider).with(project, nil).and_return(true)
      expect(EmsRefresh).to receive(:queue_refresh_task).with(manager).and_return([finished_task.id])
      expect(ExtManagementSystem).to receive(:find).with(manager.id).and_return(manager)
      expect(projects).to receive(:create!).with(params)
      allow(Notification).to receive(:create)
      expect(described_class.create_in_provider(manager.id, params)).to be_a(described_class)
      expect(Notification).to have_received(:create).with(expected_notify_creation)
    end

    it ".create_in_provider to fail(not found during refresh) and send creation notification" do
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      expect(described_class).to receive(:refresh_in_provider).with(project, nil).and_return(true)
      expect(EmsRefresh).to receive(:queue_refresh_task).and_return([finished_task.id])
      expect(ExtManagementSystem).to receive(:find).with(manager.id).and_return(manager)
      allow(Notification).to receive(:create)
      expect { described_class.create_in_provider(manager.id, params) }.to raise_error(ActiveRecord::RecordNotFound)
      expected_notify_creation[:type] = :tower_op_failure
      expect(Notification).to have_received(:create).with(expected_notify_creation)
    end

    it ".create_in_provider to succeed (with refresh_in_provider success) and send refresh in provider notification" do
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      store_new_project(project, manager)
      expect(described_class).to receive(:refresh_in_provider).with(project, nil).and_return(true)
      expect(EmsRefresh).to receive(:queue_refresh_task).and_return([finished_task.id])
      expect(ExtManagementSystem).to receive(:find).with(manager.id).and_return(manager)
      expect(projects).to receive(:create!).with(params)
      allow(Notification).to receive(:create)
      expect(described_class.create_in_provider(manager.id, params)).to be_a(described_class)
      [expected_notify_refresh_in_provider, expected_notify_creation].each do |notify|
        expect(Notification).to have_received(:create).with(notify)
      end
    end

    it ".create_in_provider to succeed (with refresh_in_provider failure) and send refresh in provider notification" do
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      store_new_project(project, manager)
      expect(described_class).to receive(:refresh_in_provider).with(project, nil).and_return(false)
      expect(EmsRefresh).to receive(:queue_refresh_task).and_return([finished_task.id])
      expect(ExtManagementSystem).to receive(:find).with(manager.id).and_return(manager)
      expect(projects).to receive(:create!).with(params)
      allow(Notification).to receive(:create)
      expected_notify_refresh_in_provider[:type] = :tower_op_failure
      expect(described_class.create_in_provider(manager.id, params)).to be_a(described_class)
      [expected_notify_refresh_in_provider, expected_notify_creation].each do |notify|
        expect(Notification).to have_received(:create).with(notify)
      end
    end

    it ".create_in_provider with credential" do
      params[:authentication_id] = credential.id
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      store_new_project(project, manager)
      expect(described_class).to receive(:refresh_in_provider).with(project, nil).and_return(true)
      expect(EmsRefresh).to receive(:queue_refresh_task).with(manager).and_return([finished_task.id])
      expect(ExtManagementSystem).to receive(:find).with(manager.id).and_return(manager)
      expected_params = params.clone.merge(:credential => 1)
      expected_params.delete(:authentication_id)
      expect(projects).to receive(:create!).with(expected_params)
      allow(Notification).to receive(:create)
      expect(described_class.create_in_provider(manager.id, params)).to be_a(described_class)
      expect(Notification).to have_received(:create).with(expected_notify_creation)
    end

    it ".create_in_provider_queue" do
      EvmSpecHelper.local_miq_server
      task_id = described_class.create_in_provider_queue(manager.id, params)
      expect(MiqTask.find(task_id)).to have_attributes(:name => "Creating #{described_class::FRIENDLY_NAME} (name=#{params[:name]})")
      expect(MiqQueue.first).to have_attributes(
        :args        => [manager.id, params],
        :class_name  => described_class.name,
        :method_name => "create_in_provider",
        :priority    => MiqQueue::HIGH_PRIORITY,
        :role        => "ems_operations",
        :zone        => manager.my_zone
      )
    end

    def store_new_project(project, manager)
      described_class.create!(
        :manager     => manager,
        :manager_ref => project.id.to_s,
        :name        => project.name,
      )
    end

    def expected_notify_action(action)
      {
        :type    => :tower_op_success,
        :options => {
          :op_name => "#{described_class::FRIENDLY_NAME} #{action}",
          :op_arg  => "(name=My Project)",
          :tower   => "EMS(manager_id=#{manager.id})"
        }
      }
    end
  end

  context "Delete through API" do
    let(:projects)      { double("AnsibleTowerClient::Collection", :find => tower_project) }
    let(:tower_project) { double("AnsibleTowerClient::Project", :destroy! => nil, :id => '1') }
    let(:project)       { described_class.create!(:manager => manager, :manager_ref => tower_project.id) }
    let(:expected_notify) do
      {
        :type    => :tower_op_success,
        :options => {
          :op_name => "#{described_class::FRIENDLY_NAME} deletion",
          :op_arg  => "(manager_ref=#{tower_project.id})",
          :tower   => "EMS(manager_id=#{manager.id})"
        }
      }
    end

    it "#delete_in_provider to succeed and send notification" do
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      expect(EmsRefresh).to receive(:queue_refresh_task).with(manager).and_return([finished_task.id])
      expect(Notification).to receive(:create).with(expected_notify)
      project.delete_in_provider
    end

    it "#delete_in_provider to fail (find the credential) and send notification" do
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      allow(projects).to receive(:find).and_raise(AnsibleTowerClient::ClientError)
      expected_notify[:type] = :tower_op_failure
      expect(Notification).to receive(:create).with(expected_notify)
      expect { project.delete_in_provider }.to raise_error(AnsibleTowerClient::ClientError)
    end

    it "#delete_in_provider_queue" do
      task_id = project.delete_in_provider_queue
      expect(MiqTask.find(task_id)).to have_attributes(:name => "Deleting #{described_class::FRIENDLY_NAME} (Tower internal reference=#{project.manager_ref})")
      expect(MiqQueue.first).to have_attributes(
        :instance_id => project.id,
        :args        => [],
        :class_name  => described_class.name,
        :method_name => "delete_in_provider",
        :priority    => MiqQueue::HIGH_PRIORITY,
        :role        => "ems_operations",
        :zone        => manager.my_zone
      )
    end
  end

  context "Update through API" do
    let(:projects)      { double("AnsibleTowerClient::Collection", :find => tower_project) }
    let(:tower_project) { double("AnsibleTowerClient::Project", :update_attributes! => {}, :id => 1) }
    let(:project)       { described_class.create!(:manager => manager, :manager_ref => tower_project.id) }
    let(:tower_cred)    { FactoryBot.create(:ansible_scm_credential, :manager_ref => '100') }

    let(:expected_notify_update) { expected_notify('update') }
    let(:expected_notify_refresh_in_provider) { expected_notify('refresh in provider') }

    it "#update_in_provider to succeed and send notification" do
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      expect(EmsRefresh).to receive(:queue_refresh_task).with(manager).and_return([finished_task.id])
      expect(described_class).to receive(:refresh_in_provider).with(tower_project, project.id).and_return(true)
      allow(Notification).to receive(:create)
      expect(tower_project).to receive(:update_attributes!).with({})
      expect(project.update_in_provider(:miq_task_id => 1, :task_id => 1)).to be_a(described_class)
      expect(Notification).to have_received(:create).with(expected_notify_update)
    end

    it "#update_in_provider to fail (at update_attributes!) and send notification" do
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      expect(tower_project).to receive(:update_attributes!).with({}).and_raise(AnsibleTowerClient::ClientError)
      allow(Notification).to receive(:create)
      expect { project.update_in_provider({}) }.to raise_error(AnsibleTowerClient::ClientError)
      expected_notify_update[:type] = :tower_op_failure
      expect(Notification).to have_received(:create).with(expected_notify_update)
    end

    it "#update_in_provider to succeed (with refresh_in_provider success) and send notification" do
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      expect(EmsRefresh).to receive(:queue_refresh_task).with(manager).and_return([finished_task.id])
      expect(described_class).to receive(:refresh_in_provider).with(tower_project, project.id).and_return(true)
      allow(Notification).to receive(:create)
      expect(project.update_in_provider({})).to be_a(described_class)
      [expected_notify_refresh_in_provider, expected_notify_update].each do |notify|
        expect(Notification).to have_received(:create).with(notify)
      end
    end

    it "#update_in_provider to succeed (with refresh_in_provider failure) and send notification" do
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      expect(EmsRefresh).to receive(:queue_refresh_task).with(manager).and_return([finished_task.id])
      expect(described_class).to receive(:refresh_in_provider).with(tower_project, project.id).and_return(false)
      allow(Notification).to receive(:create)
      expect(project.update_in_provider({})).to be_a(described_class)
      expected_notify_refresh_in_provider[:type] = :tower_op_failure
      [expected_notify_refresh_in_provider, expected_notify_update].each do |notify|
        expect(Notification).to have_received(:create).with(notify)
      end
    end

    it "#update_in_provider with credential" do
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      expect(EmsRefresh).to receive(:queue_refresh_task).with(manager).and_return([finished_task.id])
      expect(described_class).to receive(:refresh_in_provider).with(tower_project, project.id).and_return(true)
      expect(tower_project).to receive(:update_attributes!).with(:credential => tower_cred.native_ref)
      allow(Notification).to receive(:create)
      expect(project.update_in_provider(:authentication_id => tower_cred.id)).to be_a(described_class)
      expect(Notification).to have_received(:create).with(expected_notify_update)
    end

    it "#update_in_provider with nil credential" do
      expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      expect(EmsRefresh).to receive(:queue_refresh_task).with(manager).and_return([finished_task.id])
      expect(described_class).to receive(:refresh_in_provider).with(tower_project, project.id).and_return(true)
      expect(tower_project).to receive(:update_attributes!).with(:credential => nil)
      allow(Notification).to receive(:create)
      expect(project.update_in_provider(:authentication_id => nil)).to be_a(described_class)
      expect(Notification).to have_received(:create).with(expected_notify_update)
    end

    it "#update_in_provider_queue" do
      task_id = project.update_in_provider_queue({})
      expect(MiqTask.find(task_id)).to have_attributes(:name => "Updating #{described_class::FRIENDLY_NAME} (Tower internal reference=#{project.manager_ref})")
      expect(MiqQueue.first).to have_attributes(
        :instance_id => project.id,
        :args        => [{:task_id => task_id}],
        :class_name  => described_class.name,
        :method_name => "update_in_provider",
        :priority    => MiqQueue::HIGH_PRIORITY,
        :role        => "ems_operations",
        :zone        => manager.my_zone
      )
    end

    def expected_notify(action)
      {
        :type    => :tower_op_success,
        :options => {
          :op_name => "#{described_class::FRIENDLY_NAME} #{action}",
          :op_arg  => "()",
          :tower   => "EMS(manager_id=#{manager.id})"
        }
      }
    end
  end
end
