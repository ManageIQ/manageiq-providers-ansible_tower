class ManageIQ::Providers::AnsibleTower::Inventory::Parser::AutomationManager < ManageIQ::Providers::Awx::Inventory::Parser::AutomationManager
  ERROR_MAX_SIZE = 50.kilobytes

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
end
