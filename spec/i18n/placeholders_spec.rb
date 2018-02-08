describe :placeholders do
  include_examples :placeholders, ManageIQ::Providers::AnsibleTower::Engine.root.join('locale').to_s
end
