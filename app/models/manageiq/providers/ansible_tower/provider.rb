class ManageIQ::Providers::AnsibleTower::Provider < ::Provider
  has_one :automation_manager,
          :foreign_key => "provider_id",
          :class_name  => "ManageIQ::Providers::AnsibleTower::AutomationManager",
          :autosave    => true
  has_many :endpoints, :as => :resource, :dependent => :destroy, :autosave => true
  before_validation :ensure_managers
  validates :name, :presence => true, :uniqueness => true
  validates :url,  :presence => true

  PARAMS_FOR_CREATE = {
    :title  => "Configure Ansible Tower",
    :fields => [
      {
        :component  => "text-field",
        :name       => "endpoints.default.base_url",
        :label      => "URL",
        :isRequired => true,
        :validate   => [{:type => "required-validator"}]
      },
      {
        :component  => "text-field",
        :name       => "endpoints.default.username",
        :label      => "Username",
        :isRequired => true,
        :validate   => [{:type => "required-validator"}]
      },
      {
        :component  => "text-field",
        :name       => "endpoints.default.password",
        :label      => "Password",
        :type       => "password",
        :isRequired => true,
        :validate   => [{:type => "required-validator"}]
      },
      {
        :component => "checkbox",
        :name      => "endpoints.default.verify_ssl",
        :label     => "Verify SSL"
      }
    ]
  }.freeze

  def self.params_for_create
    PARAMS_FOR_CREATE
  end

  # Verify Credentials
  # args:
  # {
  #   "endpoints" => {
  #     "default" => {
  #       "base_url"   => "",
  #       "username"   => "",
  #       "password"   => "",
  #       "verify_ssl" => ""
  #     }
  #   }
  # }
  def self.verify_credentials(args)
    default_endpoint = args.dig("endpoints", "default")

    base_url, username, password, verify_ssl = default_endpoint&.values_at(
      "base_url", "username", "password", "verify_ssl"
    )
    base_url   = adjust_url(base_url)
    verify_ssl = verify_ssl ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE

    !!verify_connection(raw_connect(base_url, username, password, verify_ssl))
  end

  def self.default_api_path
    "/api/v2".freeze
  end

  def self.adjust_url(url)
    url = "https://#{url}" unless url =~ %r{\Ahttps?:\/\/} # HACK: URI can't properly parse a URL with no scheme
    URI(url).tap do |adjusted_url|
      adjusted_url.path = default_api_path if adjusted_url.path.blank?
    end
  end

  def self.verify_connection(connection)
    require 'ansible_tower_client'
    begin
      connection.api.verify_credentials ||
        raise(MiqException::MiqInvalidCredentialsError, _("Username or password is not valid"))
    rescue AnsibleTowerClient::ClientError => err
      raise MiqException::MiqCommunicationsError, err.message, err.backtrace
    end
  end

  def self.raw_connect(base_url, username, password, verify_ssl)
    require 'ansible_tower_client'
    AnsibleTowerClient.logger = $ansible_tower_log
    AnsibleTowerClient::Connection.new(
      :base_url   => base_url,
      :username   => username,
      :password   => password,
      :verify_ssl => verify_ssl
    )
  end

  def self.refresh_ems(provider_ids)
    EmsRefresh.queue_refresh(Array.wrap(provider_ids).collect { |id| [base_class, id] })
  end

  def connect(options = {})
    auth_type = options[:auth_type]
    if missing_credentials?(auth_type) && (options[:username].nil? || options[:password].nil?)
      raise _("no credentials defined")
    end

    verify_ssl = options[:verify_ssl] || self.verify_ssl
    base_url   = options[:url] || url
    username   = options[:username] || authentication_userid(auth_type)
    password   = options[:password] || authentication_password(auth_type)

    self.class.raw_connect(base_url, username, password, verify_ssl)
  end

  def verify_credentials(auth_type = nil, options = {})
    with_provider_connection(options.merge(:auth_type => auth_type)) do |c|
      self.class.verify_connection(c)
    end
  end

  def url=(new_url)
    default_endpoint.url = self.class.adjust_url(new_url).to_s
  end

  private

  def ensure_managers
    build_automation_manager unless automation_manager
    automation_manager.name    = _("%{name} Automation Manager") % {:name => name}
    if zone_id_changed?
      automation_manager.enabled = Zone.maintenance_zone&.id != zone_id
      automation_manager.zone_id = zone_id
    end
  end
end
