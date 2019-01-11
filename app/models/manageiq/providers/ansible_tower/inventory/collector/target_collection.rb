class ManageIQ::Providers::AnsibleTower::Inventory::Collector::TargetCollection < ManageIQ::Providers::Inventory::Collector
  def connection
    @connection ||= manager.connect
  end

  def initialize(_manager, _target)
    super
  end

  def inventories
    find_records(:inventory_root_groups, connection.api.inventories)
  end

  def hosts
    find_records(:configured_systems, connection.api.hosts)
  end

  def job_templates
    find_records(:configuration_scripts, connection.api.job_templates)
  end

  def configuration_workflows
    find_records(:configuration_scripts, connection.api.workflow_job_templates)
  end

  def projects
    find_records(:configuration_script_sources, connection.api.projects)
  end

  def credentials
    find_records(:credentials, connection.api.credentials)
  end

  private

  # Calls API and finds existing records.
  # @param inventory_collection_name [Symbol] IC name (as identified in persister's definitions)
  # @param endpoint - endpoint for AnsibleTowerClient api call
  def find_records(inventory_collection_name, endpoint)
    refs = references(inventory_collection_name)
    return [] if refs.blank?

    if refs.size == 1
      begin
        [endpoint.find(refs[0])]
      rescue AnsibleTowerClient::ResourceNotFoundError
        [nil]
      end
    else
      endpoint.all(:id__in => refs.join(','))
    end
  end

  # @param collection [Symbol] inventory collection name (as identified in persister's definitions)
  def references(collection)
    manager_ref = manager_ref_by_collection(collection)
    target.manager_refs_by_association.try(:[], collection).try(:[], manager_ref.to_sym).try(:to_a).try(:compact) || []
  end

  # Using first manager_ref from persister's IC definitions
  # All calls are identified by one unique ID
  def manager_ref_by_collection(inventory_collection_name)
    @tmp_persister ||= self.class.to_s.gsub('::Collector', '::Persister').constantize.new(@manager, @target)
    @tmp_persister.collections[inventory_collection_name].manager_ref[0]
  end
end
