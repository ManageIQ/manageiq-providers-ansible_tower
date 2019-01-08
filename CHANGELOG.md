# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)


## Hammer-1

### Added
- ConfigurationWorkflow only exists in under AnsibleTower::AutomationMa… [(#112)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/112)
- Support for Tower Workflow Job. [(#103)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/103)
- Service AnsibleTower and EmbeddedAnsible UI parity [(#108)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/108)
- Get stdout on ansible repository refresh [(#72)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/72)
- Integrate with Tower Workflow [(#86)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/86)
- Migrate model display names from locale/en.yml to plugin [(#55)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/55)
- To store Tower repo last_updated_on [(#59)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/59)
- Extract method raw_delete_in_provider from delete_in_provider [(#27)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/27)

### Fixed
- Tower 3.3 removed result_stdout from project_update [(#140)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/140)
- Credential.manager_ref need to be an integer for Tower 3.3 [(#134)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/134)
- Deal with ansible not having a username [(#123)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/123)
- FIX wrong VCR cassette for Embedded Ansible refresher spec [(#114)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/114)
- Collect variable Tower data upon population [(#92)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/92)
- Populate project without update job in Tower [(#82)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/82)
- tower_api.update_in_provider to remove miq_task_id from params [(#106)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/106)
- AnsibleTowerClient::Api.new now requires a version as of v0.16.0 [(#105)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/105)
- Missing files killing embedded refresh [(#97)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/97)
- Provider destroy not to destroy dependent manager automatically [(#49)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/49)
- Decrypt extra_vars before sending over to tower gem. [(#127)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/127)

### Removed
- Removing old InventoryCollection definitions [(#104)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/104)

## Gaprindashvili-6 - Released 2018-11-02

### Fixed
- Deal with ansible not having a username [(#123)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/123)

## Unreleased as of Sprint 96 ending 2018-10-08

### Fixed
- find_by 'type' is a string not a class [(#130)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/130)

## Gaprindashvili-5 - Released 2018-09-07

### Fixed
- Move #retire_now to shared code [(#66)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/66)

## Gaprindashvili-3 - Released 2018-05-15

### Added
- Tower 3.2.2 vault credential type [(#54)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/54)
- Tower Rhv credential type [(#62)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/62)
- Add host field to rhv_credential [(#69)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/69)
- Add vault credential to Ansible Tower Job. [(#70)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/70)

## Gaprindashvili-2 released 2018-03-06

### Fixed
- Dropping azure classic and rackspace credential types [(#58)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/58)

## Unreleased as of Sprint 79 ending 2018-02-12

### Added
- Use proper nested references in parser [(#47)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/47)

## Gaprindashvili-1 - Released 2018-01-31

### Added
- Add translations [(#37)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/37)
- Split #create_in_provider method into two methods. [(#25)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/25)

### Fixed
- Added supported_catalog_types [(#42)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/42)
- Correct extra_var keys to original case [(#34)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/34)
- Check if project_id is accessible [(#23)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/23)
- Adding require_nested for new azure_classic_credential [(#19)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/19)
- Allow Satellite6Credential to be removed from Embedded Ansible space [(#46)](https://github.com/ManageIQ/manageiq-providers-ansible_tower/pull/46)

## Initial changelog added
