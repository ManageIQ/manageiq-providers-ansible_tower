class ManageIQ::Providers::AnsibleTower::Inventory::Parser::AutomationManager < ManageIQ::Providers::Inventory::Parser
  ERROR_MAX_SIZE = 50.kilobytes

  def parse
    inventory_root_groups
    configured_systems
    configuration_scripts
    configuration_script_sources
    credentials
    configuration_workflows
  end

  def inventory_root_groups
    collector.inventories.each do |inventory|
      inventory_object = persister.inventory_root_groups.find_or_build(inventory.id.to_s)
      inventory_object.name = inventory.name
    end
  end

  def configured_systems
    collector.hosts.each do |host|
      inventory_object = persister.configured_systems.find_or_build(host.id)
      inventory_object.hostname = host.name
      inventory_object.virtual_instance_ref = host.instance_id
      inventory_object.inventory_root_group = persister.inventory_root_groups.lazy_find(host.inventory_id.to_s)
      inventory_object.counterpart = persister.vms.lazy_find(host.instance_id)
    end
  end

  def configuration_scripts
    provider_module = ManageIQ::Providers::Inflector.provider_module(collector.manager.class).name
    collector.job_templates.each do |job_template|
      begin
        survey_spec = job_template.survey_spec_hash
        variables   = job_template.extra_vars_hash

        inventory_root_group = persister.inventory_root_groups.lazy_find(job_template.inventory_id.to_s)
        parent               = persister.configuration_script_payloads.lazy_find(
          # checking job_template.project_id due to https://github.com/ansible/ansible_tower_client_ruby/issues/68
          # if we hit a job_template which has no related project and thus .project_id is not defined
          :configuration_script_source => persister.configuration_script_sources.lazy_find(job_template.try(:project_id)),
          :manager_ref                 => job_template.playbook
        )

        inventory_object = persister.configuration_scripts.build(
          :manager_ref          => job_template.id.to_s,
          :type                 => "#{provider_module}::AutomationManager::ConfigurationScript",
          :description          => job_template.description,
          :name                 => job_template.name,
          :survey_spec          => survey_spec,
          :variables            => variables,
          :inventory_root_group => inventory_root_group,
          :parent               => parent
        )

        configuration_script_authentications(inventory_object, job_template)
      rescue => err
        _log.warn("Failed to parse job_template ID [#{job_template&.id}]: #{err}")
        _log.debug { job_template.inspect }
      end
    end
  end

  def configuration_script_authentications(persister_configuration_script, job_template)
    %w(credential_id cloud_credential_id network_credential_id).each do |credential_attr|
      next unless job_template.respond_to?(credential_attr)

      credential_id = job_template.public_send(credential_attr).to_s
      next if credential_id.blank?

      persister.authentication_configuration_script_bases.build(
        :configuration_script_base => persister_configuration_script,
        :authentication            => persister.credentials.lazy_find(credential_id)
      )
    end
  end

  def configuration_workflows
    provider_module = ManageIQ::Providers::Inflector.provider_module(collector.manager.class).name
    collector.configuration_workflows.each do |job_template|
      begin
        inventory_object = persister.configuration_scripts.build(:manager_ref => job_template.id.to_s)
        inventory_object.type = "#{provider_module}::AutomationManager::ConfigurationWorkflow"
        inventory_object.description = job_template.description
        inventory_object.name = job_template.name
        inventory_object.survey_spec = job_template.survey_spec_hash
        inventory_object.variables = job_template.extra_vars_hash
      rescue => err
        _log.warn("Failed to parse workflow_job_template ID [#{job_template&.id}]: #{err}")
        _log.debug { job_template.inspect }
      end
    end
  end

  def configuration_script_sources
    collector.projects.each do |project|
      inventory_object = persister.configuration_script_sources.find_or_build(project.id.to_s)
      inventory_object.description = project.description
      inventory_object.name = project.name
      # checking project.credential due to https://github.com/ansible/ansible_tower_client_ruby/issues/68
      inventory_object.authentication = persister.credentials.lazy_find(project.try(:credential_id).to_s)
      inventory_object.scm_type = project.scm_type
      inventory_object.scm_url = project.scm_url
      inventory_object.scm_branch = project.scm_branch
      inventory_object.scm_clean = project.scm_clean
      inventory_object.scm_delete_on_update = project.scm_delete_on_update
      inventory_object.scm_update_on_launch = project.scm_update_on_launch
      inventory_object.status = project.status
      inventory_object.last_updated_on = project.last_updated
      inventory_object.last_update_error = nil

      unless inventory_object.status == 'successful'
        last_update = project.last_update
        inventory_object.last_update_error = last_update.stdout.mb_chars.limit(ERROR_MAX_SIZE) if last_update
      end

      project.playbooks.each do |playbook_name|
        inventory_object_playbook = persister.configuration_script_payloads.find_or_build_by(
          :configuration_script_source => inventory_object,
          :manager_ref                 => playbook_name
        )
        inventory_object_playbook.name = playbook_name
      end
    end
  end

  def miq_credential_types
    @miq_credential_types ||= begin
      provider_module = ManageIQ::Providers::Inflector.provider_module(collector.manager.class).name
      supported_types = "#{provider_module}::AutomationManager::Credential".constantize.descendants.collect(&:name)
      {
        'net'        => "#{provider_module}::AutomationManager::NetworkCredential",
        'ssh'        => "#{provider_module}::AutomationManager::MachineCredential",
        'vmware'     => "#{provider_module}::AutomationManager::VmwareCredential",
        'scm'        => "#{provider_module}::AutomationManager::ScmCredential",
        'aws'        => "#{provider_module}::AutomationManager::AmazonCredential",
        'satellite6' => "#{provider_module}::AutomationManager::Satellite6Credential",
        'gce'        => "#{provider_module}::AutomationManager::GoogleCredential",
        'azure_rm'   => "#{provider_module}::AutomationManager::AzureCredential",
        'openstack'  => "#{provider_module}::AutomationManager::OpenstackCredential",
        'rhv'        => "#{provider_module}::AutomationManager::RhvCredential",
        'vault'      => "#{provider_module}::AutomationManager::VaultCredential",
      }.select { |_tower_type, miq_type| supported_types.include?(miq_type) }
    end
  end

  def credentials
    provider_module = ManageIQ::Providers::Inflector.provider_module(collector.manager.class).name
    collector.credentials.each do |credential|
      inventory_object = persister.credentials.find_or_build(credential.id.to_s)
      inventory_object.name = credential.name
      inventory_object.userid = credential.try(:username)
      inventory_object.type = miq_credential_types[credential.kind] || "#{provider_module}::AutomationManager::Credential"
      if credential.kind == 'ssh' && !credential.vault_password.empty?
        inventory_object.type = "#{provider_module}::AutomationManager::VaultCredential"
      end
      inventory_object.options = inventory_object.type.constantize::EXTRA_ATTRIBUTES.keys.each_with_object({}) do |k, h|
        h[k] = credential.try(k)
      end
    end
  end
end
