# Cloud-1: Terraform + Ansible on AWS

Terraform provisions an Ubuntu EC2 instance, and Ansible configures it with nginx.
GitHub Actions runs the full flow on every push to `main` using AWS OIDC (no long-lived AWS keys).

> **Order matters:** create the S3 state bucket in `bootstrap/` first. Terraform uses
> it as its remote backend, so the EC2 workflow cannot start until the bucket exists.

## Quick start

1. Create the state bucket: `cd bootstrap && terraform init && terraform apply`.
2. Copy the bucket name into GitHub as `TF_STATE_BUCKET` (variable or secret).
3. Add `AWS_REGION` and the secrets described in section 4.
4. Push to `main`; the workflow creates the EC2 instance and runs Ansible.

## Repository layout

| Path | Purpose |
| --- | --- |
| `terraform/` | EC2 instance, SSH key pair, security group, and S3 remote state |
| `bootstrap/` | One-time creation of the S3 bucket used for Terraform state |
| `ansible/` | Installs nginx and deploys a landing page |
| `.github/workflows/deploy.yml` | CI/CD: Terraform apply, wait for EC2, then Ansible |

## Prerequisites

- An AWS account with a default VPC
- A GitHub repository
- Terraform >= 1.10 (the S3 backend uses native state locking)
- An SSH key pair for the `ubuntu` user

## 1. Create the Terraform state bucket (once)

```bash
cd bootstrap
terraform init
terraform apply
terraform output -raw state_bucket_name
```

Keep the bucket name; it is needed by both CI/CD and local runs.
The bootstrap state is local and is intentionally gitignored.

The default region is `eu-north-1`. To use another region, pass the same value here
and in the `AWS_REGION` GitHub variable or secret:

```bash
terraform apply -var="aws_region=us-east-1"
```

## 2. Create an SSH key pair

```bash
ssh-keygen -t ed25519 -f ~/.ssh/cloud-1 -C "cloud-1"
```

Use a dedicated key without a passphrase for CI.

## 3. Create the GitHub OIDC role

In AWS IAM, create (or reuse) the GitHub OIDC provider for
`token.actions.githubusercontent.com`, then create a role with this trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<OWNER>/<REPO>:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

Attach a policy that allows the role to manage the resources in `terraform/`:
EC2 instances, key pairs, security groups, and tags, plus `ec2:Describe*` (needed
for the AMI lookup and refresh). The role also needs `s3:ListBucket`,
`s3:GetBucketLocation`, `s3:GetObject`, `s3:PutObject`, and `s3:DeleteObject` on
the state bucket created in step 1.

## 4. Configure GitHub variables and secrets

`AWS_REGION` and `TF_STATE_BUCKET` can be repository variables or secrets; the
workflow uses the variable first and falls back to the secret.

```bash
# Option A: repository variables (recommended)
gh variable set AWS_REGION --body "eu-north-1"
gh variable set TF_STATE_BUCKET --body "<state-bucket-name>"

# Option B: repository secrets
gh secret set AWS_REGION --body "eu-north-1"
gh secret set TF_STATE_BUCKET --body "<state-bucket-name>"
```

Required secrets:

```bash
gh secret set AWS_ROLE_ARN --body "arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_NAME>"
gh secret set EC2_SSH_PRIVATE_KEY < ~/.ssh/cloud-1
gh secret set EC2_SSH_PUBLIC_KEY < ~/.ssh/cloud-1.pub
```

## 5. Deploy

Push to `main`, or run the **Deploy EC2** workflow manually from the Actions tab.

The workflow:

1. Authenticates to AWS with OIDC.
2. Runs `terraform fmt`, `init`, `validate`, `plan`, and `apply`.
3. Reads the instance public IP and waits for SSH and cloud-init.
4. Runs the Ansible playbook and verifies nginx returns HTTP 200.

## Local run

```bash
cd terraform
terraform init \
  -backend-config="bucket=<state-bucket-name>" \
  -backend-config="key=ec2/terraform.tfstate" \
  -backend-config="region=eu-north-1" \
  -backend-config="encrypt=true" \
  -backend-config="use_lockfile=true"

terraform apply \
  -var="ssh_public_key=$(cat ~/.ssh/cloud-1.pub)" \
  -var="allowed_ssh_cidr=$(curl -4 -fsS https://api.ipify.org)/32"

terraform output -raw instance_public_ip
```

If you changed the AWS region, also replace `region=eu-north-1` in the backend
config and add `-var="aws_region=<region>"` to the `terraform apply` and
`terraform destroy` commands.

Then:

```bash
cd ../ansible
cp inventory.ini.example inventory.ini
# Replace YOUR_EC2_PUBLIC_IP in inventory.ini
ansible-playbook playbook.yml --private-key ~/.ssh/cloud-1
```

## Destroy

```bash
cd terraform
terraform destroy \
  -var="ssh_public_key=$(cat ~/.ssh/cloud-1.pub)" \
  -var="allowed_ssh_cidr=$(curl -4 -fsS https://api.ipify.org)/32"
```

## Notes

- SSH access is restricted to the GitHub Actions runner's public IP and is updated on
  every deploy. For manual SSH, run Terraform locally with your own IP/32, or update
  the security group temporarily.
- The setup assumes the account has a default VPC. If it does not, add a VPC and
  subnet to `terraform/main.tf`.
- The instance serves HTTP only. Add a load balancer and TLS certificate for
  production traffic.
- The EC2 instance and the S3 state bucket are billable AWS resources. The destroy
  command above removes the EC2 resources; run `terraform destroy` in `bootstrap/`
  separately if you also want to remove the state bucket.
