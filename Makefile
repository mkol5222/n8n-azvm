.PHONY: up down init plan wait status

init:
	terraform init

plan:
	terraform plan

up: init
	terraform apply -auto-approve
	@./wait-for-n8n.sh

wait:
	@./wait-for-n8n.sh

status:
	@./wait-for-n8n.sh

down:
	terraform destroy -auto-approve
