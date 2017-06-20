# Set following env
TOWER_URL=https://10.42.0.42/api/v1
TOWER_USER=admin
TOWER_PASSWORD=1smartvm

CREDS=$TOWER_URL/credentials/
PROJECTS=$TOWER_URL/projects/
TEMPLATES=$TOWER_URL/job_templates/
HOSTS=$TOWER_URL/hosts/

curl -k -u "$TOWER_USER:$TOWER_PASSWORD" $CREDS --header 'Content-Type:application/json' -X POST -d '{"name": "hello_cred", "kind": "ssh", "username": "admin", "password": "abc", "organization": "1"}'
curl -k -u "$TOWER_USER:$TOWER_PASSWORD" $PROJECTS --header 'Content-Type:application/json' -X POST -d '{"name": "hello-repo", "scm_url":"https://github.com/jameswnl/ansible-examples", "scm_type":"git"}'
curl -k -u "$TOWER_USER:$TOWER_PASSWORD" $HOSTS --header "Content-Type:application/json" -X POST  -d '{"name": "hello_vm", "instance_id": "4233080d-7467-de61-76c9-c8307b6e4830", "inventory": "1"}'
curl -k -u "$TOWER_USER:$TOWER_PASSWORD" $TEMPLATES --header "Content-Type:application/json" -X POST  -d '{"name": "hello_job", "description": "test job", "job_type": "run", "project": "4", "playbook": "hello_world.yml", "credential": "1", "inventory": "1"}'
curl -k -u "$TOWER_USER:$TOWER_PASSWORD" $TEMPLATES --header "Content-Type:application/json" -X POST  -d '{"name": "hello_job_with_vars", "description": "test job with extra vars", "job_type": "run", "project": "4", "playbook": "hello_world.yml", "credential": "1", "inventory": "1", "extra_vars": "HELLO: World\nGOOD: Morning"}'
