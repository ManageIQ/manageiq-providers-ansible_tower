describe ManageIQ::Providers::AnsibleTower::AutomationManager::ProvisionWorkflow do
  include Spec::Support::WorkflowHelper

  let(:admin)   { FactoryBot.create(:user_with_group) }
  let(:manager) { FactoryBot.create(:automation_manager_ansible_tower) }
  let(:dialog)  { FactoryBot.create(:miq_provision_configuration_script_dialog) }

  describe "#allowed_configuration_scripts" do
    context "with no configuration_scripts or configuration_workflows" do
      it "returns an empty set" do
        workflow = described_class.new({:provision_dialog_name => dialog.name}, admin.userid)
        expect(workflow.allowed_configuration_scripts).to be_empty
      end
    end

    context "with a configuration_script" do
      let!(:configuration_script) { FactoryBot.create(:ansible_configuration_script, :manager => manager) }

      it "returns the configuration script" do
        workflow = described_class.new({:provision_dialog_name => dialog.name}, admin.userid)

        allowed = workflow.allowed_configuration_scripts
        expect(allowed.count).to eq(1)
        expect(allowed.first).to have_attributes(:id => configuration_script.id, :name => configuration_script.name)
      end
    end

    context "with a configuration_workflow" do
      let!(:configuration_workflow) { FactoryBot.create(:ansible_configuration_workflow, :manager => manager) }

      it "returns the configuration workflow" do
        workflow = described_class.new({:provision_dialog_name => dialog.name}, admin.userid)

        allowed = workflow.allowed_configuration_scripts
        expect(allowed.count).to eq(1)
        expect(allowed.first).to have_attributes(:id => configuration_workflow.id, :name => configuration_workflow.name)
      end
    end

    context "with a configuration_script and a configuration_workflow" do
      let!(:configuration_script)   { FactoryBot.create(:ansible_configuration_script,   :manager => manager) }
      let!(:configuration_workflow) { FactoryBot.create(:ansible_configuration_workflow, :manager => manager) }

      it "includes both job_templates and workflow_job_templates" do
        workflow = described_class.new({:provision_dialog_name => dialog.name}, admin.userid)

        allowed = workflow.allowed_configuration_scripts
        expect(allowed.count).to eq(2)
        expect(allowed.first).to have_attributes(:id => configuration_script.id, :name => configuration_script.name)
        expect(allowed.last).to  have_attributes(:id => configuration_workflow.id, :name => configuration_workflow.name)
      end
    end
  end
end
