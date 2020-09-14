# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'manageiq/providers/ansible_tower/version'

Gem::Specification.new do |spec|
  spec.name          = "manageiq-providers-ansible_tower"
  spec.version       = ManageIQ::Providers::AnsibleTower::VERSION
  spec.authors       = ["ManageIQ Authors"]

  spec.summary       = "ManageIQ plugin for the Ansible Tower provider."
  spec.description   = "ManageIQ plugin for the Ansible Tower provider."
  spec.homepage      = "https://github.com/ManageIQ/manageiq-providers-ansible_tower"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "ansible_tower_client", "~> 0.20", ">= 0.21.2"

  spec.add_development_dependency "simplecov"
end
