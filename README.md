# Portfolio Website Deployment
![Terraform Validation](https://github.com/samiashafique/terraform-portfolio-project/actions/workflows/terraform-pr-validation.yml/badge.svg)
![Terraform Plan](https://github.com/samiashafique/terraform-portfolio-project/actions/workflows/terraform-pr-plan.yml/badge.svg)

This repository contains the Terraform code to deploy a static Next.js portfolio website on AWS using modern Infrastructure as Code (IaC) and security best practices.
Read the full writeup: [Deploying a Next.js Portfolio with Terraform, S3, and CloudFront](https://medium.com/@samiashafique/from-project-brief-to-production-style-infrastructure-deploying-a-next-js-908f305a6253)

## Project Overview
A freelance web designer required a secure, scalable, and cost-effective solution to host their modern single-page portfolio website built with Next.js. This project demonstrates how to:
1. Deploy a static Next.js website using Amazon S3.
2. Deliver content globally with Amazon CloudFront.
3. Secure the S3 bucket using Origin Access Control (OAC).
4. Block all public access to the S3 bucket.
5. Enable server-side encryption for objects stored in S3.
6. Manage AWS infrastructure using Terraform.
7. Store Terraform state remotely in Amazon S3, using Terraform's native S3 lockfile for state locking.
8. Validate and plan Terraform changes automatically on every pull request using GitHub Actions, authenticated via short-lived OIDC credentials (no static AWS access keys).

## Architecture

![Architecture Diagram](docs/terraform-portfolio-website.png)

## Prerequisites
-  Terraform CLI - https://developer.hashicorp.com/terraform/install
-  AWS CLI - https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
-  AWS Account with permissions to create S3, CloudFront, and IAM resources
-  Node.js and npm
-  A GitHub repository variable named `AWS_ROLE_ARN` (see [Bootstrapping](#bootstrapping-the-remote-backend-and-ci-role) below) if you want the CI workflows to run

## CI/CD Pipeline
Terraform changes are checked automatically before code review using two GitHub Actions workflows, both triggered on pull requests that touch `terraform/**`.

**1. Validate** — checks the config without touching AWS:
1. Checks Terraform formatting (`terraform fmt -check`)
2. Initializes Terraform without the remote backend (`terraform init -backend=false`)
3. Validates the configuration (`terraform validate`)

See the full writeup: [Infrastructure Delivery with GitHub Actions: Part 1](https://medium.com/@samiashafique/production-style-infrastructure-delivery-with-github-actions-part-1-validating-terraform-changes-bd9649f9704a).

**2. Plan** — shows the reviewer exactly what will change in AWS before the PR merges:
1. Assumes a read-only IAM role via GitHub OIDC (short-lived credentials, no stored secrets)
2. Initializes Terraform against the real S3 backend
3. Runs `terraform plan` and posts the result as a comment on the pull request, updating the same comment on subsequent pushes

<!-- TODO: link Part 2 of the article series once published -->

*Automated `apply` on merge is covered in a later part of this series.*

## Bootstrapping the Remote Backend and CI Role
Before initializing Terraform, create the remote backend that stores the Terraform state, and the IAM role the CI workflows assume via OIDC. Both are chicken-and-egg problems — CI can't create the role it needs to run — so this part is applied manually, once, from your machine.

> **Note:** This project uses the **Canada (Central) (`ca-central-1`)** AWS Region. Replace `your-unique-backend-bucket-name` with a globally unique S3 bucket name and update `backend.tf` in both `terraform/` and `bootstrap/` accordingly.

### 1. Create the S3 bucket
```bash
aws s3api create-bucket \
  --bucket your-unique-backend-bucket-name \
  --region ca-central-1 \
  --create-bucket-configuration LocationConstraint=ca-central-1
```

### 2. Enable bucket versioning
```bash
aws s3api put-bucket-versioning \
  --bucket your-unique-backend-bucket-name \
  --versioning-configuration Status=Enabled
```

### 3. Enable server-side encryption
```bash
aws s3api put-bucket-encryption \
  --bucket your-unique-backend-bucket-name \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'
```

State locking uses Terraform's native S3 lockfile support (`use_lockfile = true`) — no DynamoDB table is required.

### 4. Apply the bootstrap config
This creates the GitHub OIDC provider and the plan-only IAM role (`bootstrap/oidc.tf`):
```bash
cd bootstrap
terraform init
terraform apply
```

### 5. Configure the GitHub repository variable
Copy the `role_arn` output from the bootstrap apply and add it as a repository variable so the plan workflow can assume it:
```bash
terraform output role_arn
```
In GitHub: **Settings → Secrets and variables → Actions → Variables** → add `AWS_ROLE_ARN` with that value.

Once the backend resources exist and the role is bootstrapped, update the S3 bucket name in `terraform/backend.tf` to match the bucket you created above. You can then continue with the deployment steps below.

## Steps to Deploy

### 1. Clone the repository
```bash
git clone https://github.com/samiashafique/terraform-portfolio-project.git
cd terraform-portfolio-project
```

### 2. Build the Next.js application
```bash
cd portfolio-website
npm install
npm run build
```
This generates a static version of the website in the `out` directory.

### 3. Initialize Terraform
```bash
cd ../terraform
terraform init
```

### 4. Review and deploy the infrastructure
```bash
terraform plan
terraform apply
```
Terraform provisions the following AWS resources:
- Amazon S3 bucket
- CloudFront distribution
- Origin Access Control (OAC)
- Bucket policy
- Bucket ownership controls
- Public access block
- Server-side encryption

### 5. Upload the website
```bash
aws s3 sync ../portfolio-website/out s3://your-website-bucket-name
```
> **Note:** Replace your-website-bucket-name with the S3 bucket name configured in terraform/main.tf.

### 6. Access the website
Retrieve the CloudFront URL:
```bash
terraform output cloudfront_url
```
Open the CloudFront URL in your browser to view the deployed website.

## Security Best Practices Implemented
- Private Amazon S3 bucket
- CloudFront Origin Access Control (OAC)
- S3 Public Access Block enabled
- Bucket Ownership Controls
- Server-side encryption (AES256)
- HTTPS enforced through CloudFront
- Least-privilege bucket policy
- Remote Terraform state with native S3 state locking
- Short-lived OIDC credentials for CI (no static AWS access keys), scoped by a trust policy restricted to `pull_request` events on this repository
- CI IAM role permissions restricted to read-only plus a single-object S3 lock permission — no write access to actual infrastructure

## Future Improvements
* Automated `apply` on merge to main, gated by approval (in progress — see Part 3 of the article series)
* Scope the plan role's permissions from the actual API calls `terraform plan` makes, instead of the broad `ReadOnlyAccess` managed policy currently attached
* Extend the validation workflow's `terraform/**` path filter to also cover changes under `bootstrap/`
* Refactor the configuration to use input variables instead of hardcoded values
