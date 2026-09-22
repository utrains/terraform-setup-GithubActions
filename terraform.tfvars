# Copy this file to terraform.tfvars and fill in your own values.
# terraform.tfvars is gitignored because it holds secrets - never commit it.

aws_region = "us-east-1"

# we need a t2.large server to run this lab, as it allows multiple servers to be deployed.
aws_instance_type_server = "t2.large"

# Credentials to store in Vault for JFrog. Change these before use.
jfrog_secret_username_and_password = ["admin", "changeme"]
jfrog_secret_token                 = "changeme"
