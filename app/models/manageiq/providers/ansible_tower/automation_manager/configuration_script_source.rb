class ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScriptSource <
  ManageIQ::Providers::ExternalAutomationManager::ConfigurationScriptSource

  include ManageIQ::Providers::AnsibleTower::AutomationManager::TowerApi
  include ProviderObjectMixin

  supports :create

  def self.provider_params(params)
    if params.keys.include?(:authentication_id)
      authentication_id = params.delete(:authentication_id)
      params[:credential] = authentication_id ? Authentication.find(authentication_id).native_ref : nil
    end
    params
  end

  def self.provider_collection(manager)
    manager.with_provider_connection do |connection|
      connection.api.projects
    end
  end

  def self.notify_on_provider_interaction?
    true
  end

  def self.refresh_in_provider(project, id = nil)
    return false unless project.can_update?

    project_update = project.update

    # this is really just a quick hack. We should do this properly once
    # https://github.com/ManageIQ/manageiq/pull/14405 is merged
    log_header = "updating project #{project.id} (#{name} #{id})"
    _log.info "#{log_header}..."
    Timeout.timeout(5.minutes) do
      loop do
        project_update = project_update.api.project_updates.find(project_update.id)
        # the sleep here is also needed because tower needs some time to actually propagate it's updates
        # if we would return immediately it _could_ be that the we get the old playbooks
        # the whole sleep business is a workaround anyway until we get proper polling via the PR mentioned above
        sleep REFRESH_ON_TOWER_SLEEP
        break if project_update.finished.present?
      end
    end

    if project_update.failed
      _log.info "#{log_header}...Failed"
      false
    else
      _log.info "#{log_header}...Complete"
      true
    end
  end

  def provider_object(connection = nil)
    (connection || connection_source.connect).api.projects.find(manager_ref)
  end

  REFRESH_ON_TOWER_SLEEP = 1.second
  def refresh_in_provider
    with_provider_object do |project|
      self.class.refresh_in_provider(project, id)
    end
  end

  FRIENDLY_NAME = 'Ansible Tower Project'.freeze
end
