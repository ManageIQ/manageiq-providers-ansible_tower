class ManageIQ::Providers::AnsibleTower::AutomationManager < ManageIQ::Providers::ExternalAutomationManager
  include ProcessTasksMixin

  class << self
    delegate :params_for_create,
             :verify_credentials,
             :to => ManageIQ::Providers::AnsibleTower::Provider
  end

  delegate :authentications,
           :authentications=,
           :authentication_check,
           :authentication_status,
           :authentication_status_ok?,
           :connect,
           :endpoints,
           :endpoints=,
           :url,
           :url=,
           :verify_credentials,
           :with_provider_connection,
           :to => :provider

  belongs_to :provider, :autosave => true, :dependent => :destroy
  after_save :change_maintenance_for_provider, :if => proc { |ems| ems.saved_change_to_enabled? }

  require_nested :Credential
  require_nested :AmazonCredential
  require_nested :AzureCredential
  require_nested :CloudCredential
  require_nested :GoogleCredential
  require_nested :MachineCredential
  require_nested :VaultCredential
  require_nested :NetworkCredential
  require_nested :OpenstackCredential
  require_nested :ScmCredential
  require_nested :Satellite6Credential
  require_nested :VmwareCredential
  require_nested :RhvCredential

  require_nested :ConfigurationScript
  require_nested :ConfigurationScriptSource
  require_nested :ConfigurationWorkflow
  require_nested :ConfiguredSystem
  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :Inventory
  require_nested :Job
  require_nested :Playbook
  require_nested :Refresher
  require_nested :RefreshWorker
  require_nested :WorkflowJob

  def self.connection_source(options = {})
    options[:connection_source] || self
  end
  private_class_method :connection_source

  def image_name
    "ansible"
  end

  def change_maintenance_for_provider
    provider.save
  end

  def self.ems_type
    @ems_type ||= "ansible_tower_automation".freeze
  end

  def self.description
    @description ||= "Ansible Tower Automation".freeze
  end

  def self.catalog_types
    {"generic_ansible_tower" => N_("Ansible Tower")}
  end

  def self.display_name(number = 1)
    n_('Automation Manager (Ansible Tower)', 'Automation Managers (Ansible Tower)', number)
  end

  def self.create_from_params(params, endpoints, authentications)
    new(params).tap do |ems|
      endpoints.each { |endpoint| ems.assign_nested_endpoint(endpoint) }
      authentications.each { |authentication| ems.assign_nested_authentication(authentication) }

      ems.provider.save!
      ems.save!
    end
  end

  def edit_with_params(params, endpoints, authentications)
    tap do |ems|
      transaction do
        # Remove endpoints/attributes that are not arriving in the arguments above
        ems.endpoints.where.not(:role => nil).where.not(:role => endpoints.map { |ep| ep['role'] }).delete_all
        ems.authentications.where.not(:authtype => nil).where.not(:authtype => authentications.map { |au| au['authtype'] }).delete_all

        ems.assign_attributes(params)
        ems.endpoints = endpoints.map(&method(:assign_nested_endpoint))
        ems.authentications = authentications.map(&method(:assign_nested_authentication))

        ems.provider.save!
        ems.save!
      end
    end
  end
  delegate :name=, :zone, :zone=, :zone_id, :zone_id=, :to => :provider

  def name
    "#{provider.name} Automation Manager"
  end

  def provider
    super || ensure_provider
  end

  private

  def ensure_provider
    build_provider.tap { |p| p.automation_manager = self }
  end
end
