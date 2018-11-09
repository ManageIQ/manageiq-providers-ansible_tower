$:.push File.expand_path("../lib", __FILE__)

require "manageiq/providers/ansible_tower/version"

Gem::Specification.new do |s|
  s.name        = "manageiq-providers-ansible_tower"
  s.version     = ManageIQ::Providers::AnsibleTower::VERSION
  s.authors     = ["ManageIQ Developers"]
  s.homepage    = "https://github.com/ManageIQ/manageiq-providers-ansible_tower"
  s.summary     = "AnsibleTower Provider for ManageIQ"
  s.description = "AnsibleTower Provider for ManageIQ"
  s.licenses    = ["Apache-2.0"]

  s.files = Dir["{app,config,lib}/**/*"]

  s.add_runtime_dependency "ansible_tower_client", "~> 0.19"

  s.add_development_dependency "codeclimate-test-reporter", "~> 1.0.0"
  s.add_development_dependency "simplecov"
end
