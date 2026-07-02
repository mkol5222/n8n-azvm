.PHONY: up down init plan wait status import-workflows

init:
	terraform init

plan:
	terraform plan

up: init
	terraform apply -auto-approve
	@./wait-for-n8n.sh
	@./scripts/import-workflows.sh

wait:
	@./wait-for-n8n.sh

status:
	@./wait-for-n8n.sh

down:
	terraform destroy -auto-approve

import-workflows:
	@./scripts/import-workflows.sh
