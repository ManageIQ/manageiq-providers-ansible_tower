module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::RhvCredential
  COMMON_ATTRIBUTES = {
    :userid => {
      :label     => N_('Username'),
      :help_text => N_('Username for this credential')
    },
    :password => {
      :type      => :password,
      :label     => N_('Password'),
      :help_text => N_('Password for this credential')
    }
  }.freeze

  EXTRA_ATTRIBUTES = {
    :host => {
      :type       => :string,
      :label      => N_('Host'),
      :help_text  => N_('The host to authenticate with'),
      :max_length => 1024,
      :required   => true
    }
  }.freeze

  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze

  API_OPTIONS = {
    :label      => N_('Red Hat Virtualization'),
    :type       => 'cloud',
    :attributes => API_ATTRIBUTES
  }.freeze
  TOWER_KIND = 'rhv'.freeze
end
