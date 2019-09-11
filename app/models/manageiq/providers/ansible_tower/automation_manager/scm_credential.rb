class ManageIQ::Providers::AnsibleTower::AutomationManager::ScmCredential < ManageIQ::Providers::AnsibleTower::AutomationManager::Credential
  def self.display_name(number = 1)
    n_('Credential (SCM)', 'Credentials (SCM)', number)
  end

  COMMON_ATTRIBUTES = {
    :userid   => {
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
    :ssh_key_unlock => {
      :type       => :password,
      :label      => N_('Private key passphrase'),
      :help_text  => N_('Passphrase to unlock SSH private key if encrypted'),
      :max_length => 1024
    },
    :ssh_key_data   => {
      :type      => :password,
      :multiline => true,
      :label     => N_('Private key'),
      :help_text => N_('RSA or DSA private key to be used instead of password')
    }
  }.freeze

  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze

  API_OPTIONS = {
    :label      => N_('Scm'),
    :type       => 'scm',
    :attributes => API_ATTRIBUTES
  }.freeze
  TOWER_KIND = 'scm'.freeze
end
