.PHONY: install-go install-terraform build move-bin

install: install-go install-terraform build move-bin

install-terraform:
	@if ! [ -x "$$(command -v terraform)" ]; then \
		echo "Terraform is not installed. Installing..."; \
		curl -O https://releases.hashicorp.com/terraform/0.12.24/terraform_0.12.24_linux_amd64.zip; \
		unzip terraform_0.12.24_linux_amd64.zip; \
		sudo mv terraform /usr/local/bin/; \
	else \
		echo "Terraform is already installed"; \
	fi

build:
	@go build -o presspilot cmd/main.go

move-bin:
	@sudo mv presspilot /usr/bin
	@echo "Build complete. You can run the program with presspilot."
