class ManageIQ::Providers::AnsibleTower::AutomationManager < ManageIQ::Providers::ExternalAutomationManager
  include ProcessTasksMixin

  class << self
    delegate :params_for_create,
             :verify_credentials,
             :to => ManageIQ::Providers::AnsibleTower::Provider
  end

  delegate :authentications,
           :authentication_check,
           :authentication_status,
           :authentication_status_ok?,
           :connect,
           :verify_credentials,
           :with_provider_connection,
           :to => :provider

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
    if provider.present? && saved_change_to_zone_id?
      provider.zone_id = zone_id
      provider.save
    end
  end

  def inventory_object_refresh?
    true
  end

  def self.ems_type
    @ems_type ||= "ansible_tower_automation".freeze
  end

  def self.description
    @description ||= "Ansible Tower Automation".freeze
  end

  def supported_catalog_types
    %w(generic_ansible_tower)
  end

  def self.display_name(number = 1)
    n_('Automation Manager (Ansible Tower)', 'Automation Managers (Ansible Tower)', number)
  end
end
