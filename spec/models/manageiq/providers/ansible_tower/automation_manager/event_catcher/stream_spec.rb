describe ManageIQ::Providers::AnsibleTower::AutomationManager::EventCatcher::Stream do
  include_context "uses tower_data.yml"

  let(:auth_userid) { Rails.application.secrets.ansible_tower[:user] }
  let(:auth_password) { Rails.application.secrets.ansible_tower[:password] }

  let(:cassette_file) { described_class.name.underscore.to_s }
  let(:auth)                    { FactoryBot.create(:authentication, :userid => auth_userid, :password => auth_password) }
  let(:automation_manager)      { provider.automation_manager }
  let(:provider) do
    FactoryBot.create(:provider_ansible_tower,
                       :url        => Rails.application.secrets.ansible_tower[:url],
                       :verify_ssl => false,).tap { |provider| provider.authentications << auth }
  end

  let(:spec_test_org_id) { tower_data[:items]['spec_test_org'][:id] }
  let(:user_id) { tower_data[:user][:id] }

  subject do
    described_class.new(automation_manager)
  end

  context "#poll" do
    it "yields valid events" do
      VCR.use_cassette(cassette_file) do
        last_activity = subject.send(:last_activity)
        # do something on tower that creates an activity in activity_stream
        provider.connect.api.credentials.create!(:organization => spec_test_org_id,
                                                  :name         => 'test_stream',
                                                  :user         => user_id)
        polled_event = nil
        subject.poll do |event|
          expect(event['id']).to eq(last_activity.id + 1)
          subject.stop
          polled_event = event
        end
        expect(subject.send(:last_activity).id).to eq(polled_event['id'])
      end
    end
  end
end
