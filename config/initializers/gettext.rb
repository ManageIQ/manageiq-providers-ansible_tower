Vmdb::Gettext::Domains.add_domain(
  'ManageIQ_Providers_AnsibleTower',
  ManageIQ::Providers::AnsibleTower::Engine.root.join('locale').to_s,
  :po
)
