FactoryGirl.define do
  trait :ansible_with_vcr_authentication do
    zone do
      _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
      zone
    end
    verify_ssl false
    url Rails.application.secrets.ansible.try(:[], 'url') || 'ANSIBLE_URL'

    after(:create) do |ems|
      userid = Rails.application.secrets.ansible.try(:[], 'userid') || 'ANSIBLE_USERID'
      password = Rails.application.secrets.ansible.try(:[], 'password') || 'ANSIBLE_PASSWORD'

      ems.authentications << FactoryGirl.create(
        :authentication,
        :userid   => userid,
        :password => password
      )
    end
  end
end
