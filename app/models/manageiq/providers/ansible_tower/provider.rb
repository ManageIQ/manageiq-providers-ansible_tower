class ManageIQ::Providers::AnsibleTower::Provider < ::Provider
  has_one :automation_manager,
          :foreign_key => "provider_id",
          :class_name  => "ManageIQ::Providers::AnsibleTower::AutomationManager",
          :autosave    => true
  delegate :url=, :to => :default_endpoint
  has_many :endpoints, :as => :resource, :dependent => :destroy, :autosave => true
  before_validation :ensure_managers
  validates :name, :presence => true, :uniqueness => true
  validates :url,  :presence => true

  def self.params_for_create
    {
      :fields => [
        {
          :component => 'sub-form',
          :id        => 'endpoints-subform',
          :name      => 'endpoints-subform',
          :title     => _("Endpoint"),
          :fields    => [
            {
              :component              => 'validate-provider-credentials',
              :id                     => 'authentications.default.valid',
              :name                   => 'authentications.default.valid',
              :skipSubmit             => true,
              :isRequired             => true,
              :validationDependencies => %w[type zone_id],
              :fields                 => [
                {
                  :component  => "text-field",
                  :id         => "endpoints.default.url",
                  :name       => "endpoints.default.url",
                  :label      => _("URL"),
                  :isRequired => true,
                  :validate   => [{:type => "required"}]
                },
                {
                  :component    => "select",
                  :id           => "endpoints.default.verify_ssl",
                  :name         => "endpoints.default.verify_ssl",
                  :label        => _("SSL verification"),
                  :dataType     => "integer",
                  :isRequired   => true,
                  :initialValue => OpenSSL::SSL::VERIFY_PEER,
                  :options      => [
                    {
                      :label => _('Do not verify'),
                      :value => OpenSSL::SSL::VERIFY_NONE,
                    },
                    {
                      :label => _('Verify'),
                      :value => OpenSSL::SSL::VERIFY_PEER,
                    },
                  ]
                },
                {
                  :component  => "text-field",
                  :id         => "authentications.default.userid",
                  :name       => "authentications.default.userid",
                  :label      => _("Username"),
                  :helperText => _("Should have privileged access, such as root or administrator."),
                  :isRequired => true,
                  :validate   => [{:type => "required"}]
                },
                {
                  :component  => "password-field",
                  :id         => "authentications.default.password",
                  :name       => "authentications.default.password",
                  :label      => _("Password"),
                  :type       => "password",
                  :isRequired => true,
                  :validate   => [{:type => "required"}]
                },
              ],
            },
          ],
        },
      ]
    }.freeze
  end

  # Verify Credentials
  # args: {
  #  "endpoints" => {
  #    "default" => {
  #       "url" => nil,
  #       "verify_ssl" => nil
  #    },
  #  },
  #  "authentications" => {
  #     "default" => {
  #       "userid" => nil,
  #       "password" => nil,
  #     }
  #   }
  # }
  def self.verify_credentials(args)
    default_authentication = args.dig("authentications", "default")
    url = args.dig("endpoints", "default", "url")
    verify_ssl = args.dig("endpoints", "default", "verify_ssl")

    userid   = default_authentication["userid"]
    password = ManageIQ::Password.try_decrypt(default_authentication["password"])
    password ||= find(args["id"]).authentication_password

    verify_connection(raw_connect(url, userid, password, verify_ssl))
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

  def self.raw_connect(url, username, password, verify_ssl)
    base_url = adjust_url(url).to_s

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

  def name=(val)
    super(val&.sub(/ Automation Manager$/, ''))
  end

  private

  def ensure_managers
    build_automation_manager unless automation_manager
    automation_manager.provider = self

    if zone_id_changed?
      automation_manager.zone    = zone
      automation_manager.enabled = Zone.maintenance_zone&.id != zone_id
    end
  end
end
