.PHONY: init-dev plan-dev apply-dev destroy-dev \
        init-prod plan-prod apply-prod destroy-prod \
        init-dr plan-dr apply-dr destroy-dr \
        fmt validate clean

# Development environment commands
init-dev:
	cd environments/dev && terraform init

plan-dev:
	cd environments/dev && terraform plan -out=tfplan

apply-dev:
	cd environments/dev && terraform apply tfplan

destroy-dev:
	cd environments/dev && terraform destroy

# Production environment commands
init-prod:
	cd environments/prod && terraform init

plan-prod:
	cd environments/prod && terraform plan -out=tfplan

apply-prod:
	cd environments/prod && terraform apply tfplan

destroy-prod:
	cd environments/prod && terraform destroy

# DR environment commands
init-dr:
	cd environments/dr-pilot-light && terraform init

plan-dr:
	cd environments/dr-pilot-light && terraform plan -out=tfplan

apply-dr:
	cd environments/dr-pilot-light && terraform apply tfplan

destroy-dr:
	cd environments/dr-pilot-light && terraform destroy

# Common commands
fmt:
	terraform fmt -recursive

validate:
	cd environments/dev && terraform validate
	cd environments/prod && terraform validate
	cd environments/dr-pilot-light && terraform validate

clean:
	find . -type d -name ".terraform" -exec rm -rf {} +
	find . -type f -name "*.tfplan" -delete
	find . -type f -name ".terraform.lock.hcl" -delete