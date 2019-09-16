class ManageIQ::Providers::AnsibleTower::Inventory::Collector::TargetCollection < ManageIQ::Providers::Inventory::Collector
  MAX_FILTER_SIZE = 200

  def connection
    @connection ||= manager.connect
  end

  def initialize(_manager, _target)
    super

    infer_related_manager_refs!
  end

  def inventories
    find_records(:inventory_root_groups, connection.api.inventories)
  end

  def hosts
    return @hosts if @hosts.present?
    @hosts = find_records(:configured_systems, connection.api.hosts)
  end

  def job_templates
    return @job_templates if @job_templates.present?
    @job_templates = find_records(:configuration_scripts, connection.api.job_templates)
  end

  def configuration_workflows
    find_records(:configuration_scripts, connection.api.workflow_job_templates)
  end

  def projects
    return @projects if @projects.present?
    @projects = find_records(:configuration_script_sources, connection.api.projects)
  end

  def credentials
    find_records(:credentials, connection.api.credentials)
  end

  protected

  def infer_related_manager_refs!
    if references(:configured_systems).present?
      hosts.each do |host|
        add_simple_target!(:inventory_root_groups, host.inventory_id.to_s)
      end
    end

    if references(:configuration_scripts).present?
      job_templates.each do |job_template|
        add_simple_target!(:inventory_root_groups, job_template.inventory_id.to_s)
        add_simple_target!(:configuration_script_sources, job_template.try(:project_id)) if job_template.try(:project_id).present?
        %w(credential_id cloud_credential_id network_credential_id).each do |credential_attr|
          next unless job_template.respond_to?(credential_attr)
          credential_id = job_template.public_send(credential_attr).to_s
          next if credential_id.blank?
          add_simple_target!(:credentials, credential_id)
        end
      end
    end

    # target was added in previous block, compute references again
    target.manager_refs_by_association_reset
    if references(:configuration_script_sources)
      projects.each do |project|
        add_simple_target!(:credentials, project.credential_id.to_s)
      end
    end

    target.manager_refs_by_association_reset
  end

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
        []
      end
    else
      multi_query(refs) do |refs_batch|
        # returns Enumeration
        endpoint.all(:id__in => refs_batch.join(','))
      end
    end
  end

  def multi_query(refs)
    refs.each_slice(MAX_FILTER_SIZE).map { |refs_batch| yield(refs_batch) }.lazy.flat_map(&:lazy)
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

  def add_simple_target!(association, ems_ref)
    return if ems_ref.blank?

    target.add_target(:association => association, :manager_ref => { manager_ref_by_collection(association) => ems_ref })
  end
end
