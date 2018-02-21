module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::VaultCredential
  COMMON_ATTRIBUTES = {}.freeze

  EXTRA_ATTRIBUTES = {
    :vault_password => {
      :type       => :password,
      :label      => N_('Vault password'),
      :help_text  => N_('Vault password'),
      :max_length => 1024
    }
  }.freeze

  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze

  API_OPTIONS = {
    :label      => N_('Vault'),
    :type       => 'vault',
    :attributes => API_ATTRIBUTES
  }.freeze
  TOWER_KIND = 'ssh'.freeze
end
