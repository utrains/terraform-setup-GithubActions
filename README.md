# CI/CD Tools Server on AWS

Terraform project that builds a single EC2 server on AWS and installs a small set of DevOps tools on it:

| Tool | Port | How it's installed |
|---|---|---|
| JFrog Artifactory OSS 7.68.20 | 8082 (UI), 8081 (router) | tarball in `/opt`, run as a systemd service |
| SonarQube (LTS community) | 9000 | Docker container |
| HashiCorp Vault | 8200 | yum package, systemd service |
| Java 17, Maven 3.9.5, sonar-scanner 4.8 | - | installed on the server, env vars in `/etc/profile.d/java_path.sh` |

## What Terraform creates

- A VPC (`10.0.0.0/16`) with one public subnet, an internet gateway and a route table
- A security group opening ports 22, 80, 4954, 8081, 8082, 9000 and 8200 to `0.0.0.0/0`
- An RSA key pair, saved locally as `server_key.pem`
- One Amazon Linux 2023 EC2 instance (`t2.large`, 50 GB disk), no IAM role attached

## How it runs

1. The instance boots and `installations_scripts/` is copied to `/home/ec2-user/`.
2. `prepare_server` runs `yum update`, installs `dos2unix`, fixes the scripts' line endings, and installs Docker (needed by the SonarQube step below).
3. The install scripts run in this order:
   - `install_java.sh`
   - `install_jfrog.sh`
   - `install_sonar_using_docker.sh`
   - `install_vault.sh`, which initialises and unseals Vault, enables a `secrets` KV store and saves the JFrog credentials in it
4. `fetch_remote_file` copies `*.txt` from the server back to this folder over `scp`. This brings back `vaultkey.txt`, which holds the Vault unseal key and root token.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install)
- An AWS CLI profile with permission to create VPC and EC2 resources (default profile name: `default`)
- `ssh` and `scp` available on your machine

## Usage

```bash
terraform init
terraform apply
```

When it finishes, Terraform prints the SSH command and the URLs for JFrog, Vault and SonarQube.

To tear everything down:

```bash
terraform destroy
```

## Configuration

Set in `terraform.tfvars` (defaults are in `var.tf`):

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `us-east-1` | AWS region |
| `profile` | `default` | AWS CLI profile |
| `aws_instance_type_server` | `t2.large` | Instance type |
| `jfrog_secret_username_and_password` | none, required | `[username, password]` stored in Vault |
| `jfrog_secret_token` | none, required | Token stored in Vault |

## Outputs

| Output | Meaning |
|---|---|
| `ssh_connexion` | SSH command to reach the server |
| `JFROG_URL` | `http://<ip>:8082` |
| `HASHICORP_VAULT_URL` | `http://<ip>:8200` |
| `Vault_root_token` | Name of the file holding the token (`vaultkey.txt`) |
| `sonarqube_url` | `http://<ip>:9000` |
| `sonarqube_credentials` | Default SonarQube login (`admin / admin`) |

## Using SonarCloud instead of the local SonarQube (free account)

SonarCloud (now branded **SonarQube Cloud**) is Sonar's hosted service. It needs no Docker and no server of your own, so it is a good alternative to the SonarQube container while that step is broken. The server already has `sonar-scanner` installed at `/opt/sonar-scanner`, and it can send its results to SonarCloud.

### 1. Create the free account

1. Go to [sonarcloud.io](https://sonarcloud.io) and choose **Log in**.
2. Sign in with your GitHub, GitLab, Bitbucket or Azure DevOps account. Your SonarCloud account is created and linked to that account.
3. Choose **Import an organization** from your DevOps platform and authorise the SonarCloud app on your account or organization. (You can also choose **create one manually** if you don't want to link a repository host.)
4. Give the organization a name and a key, and remember the **organization key**. You will need it later.
5. On the plan page, select the **Free** plan and click **Create Organization**.

Free plan limits:

- Up to **50k lines of code** across the organization.
- Code and analysis results are **publicly visible** at sonarcloud.io/explore/projects, so use it only for code you are happy to make public.

### 2. Import a project

1. Click **+** > **Analyze new project**.
2. Pick the repositories to analyze and click **Set Up**.
3. Choose **With other CI tools** (or the method that fits) when asked how to analyze it. SonarCloud then shows the **project key** and the exact commands for your setup.

### 3. Generate a token

1. Click your avatar > **My Account** > **Security**.
2. Enter a token name (for example `ci-token`) and click **Generate Token**.
3. Copy the token right away. It is shown only once. Treat it like a password and never commit it.

### 4. Run an analysis from the server

SSH into the server (see the `ssh_connexion` output), go to the project's source folder and run:

```bash
export SONAR_TOKEN=<your-token>

/opt/sonar-scanner/bin/sonar-scanner \
  -Dsonar.host.url=https://sonarcloud.io \
  -Dsonar.organization=<your-organization-key> \
  -Dsonar.projectKey=<your-project-key> \
  -Dsonar.sources=.
```

`sonar-scanner` is not on the `PATH` in this setup, so use the full path shown above. The scanner reads the token from `SONAR_TOKEN`. For Maven projects, `mvn sonar:sonar` with the same `sonar.*` properties also works. Results appear in your SonarCloud project after a minute or two.

If SonarCloud's setup page shows different commands or a different host URL, follow those. It is the source of truth for your account.

## Known issues and warnings

- **`terraform.tfvars` contains the JFrog password and token in plain text.** Do not commit it to a public repository. Use `terraform.tfvars.example` as a template.
- **The generated files hold secrets**: `server_key.pem` (SSH private key) and `vaultkey.txt` (Vault root token). The Terraform state also contains the private key. Keep all of them out of version control.
- **Every port is open to the whole internet**, and Vault runs without TLS. Restrict the security group to your own IP for anything beyond a short-lived lab.
- **Change the default logins** (SonarQube `admin / admin`, JFrog `admin / password`) after first login.
- The security group still opens port 4954, which nothing uses now.
