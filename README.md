# Portfolio Website Deployment
![Terraform Validation](https://github.com/samiashafique/terraform-portfolio-project/actions/workflows/terraform-pr-validation.yml/badge.svg)
![Terraform Plan](https://github.com/samiashafique/terraform-portfolio-project/actions/workflows/terraform-pr-plan.yml/badge.svg)
![Terraform Apply](https://github.com/samiashafique/terraform-portfolio-project/actions/workflows/terraform-apply.yml/badge.svg)

This repository contains the Terraform code to deploy a static Next.js portfolio website on AWS, and the GitHub Actions workflows that deliver changes to it through review, approval, and short-lived credentials.

Read the writeup on the initial infrastructure and design decisions: [Deploying a Next.js Portfolio on AWS: From Static Website to Production-Style Infrastructure](https://medium.com/@samiashafique/from-project-brief-to-production-style-infrastructure-deploying-a-next-js-908f305a6253). The CI/CD pipeline added since then is covered in its own article series, linked in the [CI/CD Pipeline](#cicd-pipeline) section below.

## Project Overview
The project began with a simple design brief: deploy a static Next.js portfolio website on AWS in a way that is highly available, globally accessible, secure, scalable, and cost-effective.

Once the infrastructure existed, a second question followed. Every change to it was being made from a laptop, using administrator credentials, with nothing recording what changed or why. So the project extended: getting changes into that infrastructure through review and approval, without storing any long-lived AWS credentials anywhere.

The website itself is small on purpose. It is enough production infrastructure to be worth protecting, without adding services that are not needed.

This project demonstrates how to:
1. Deploy a static Next.js website using Amazon S3.
2. Deliver content globally with Amazon CloudFront.
3. Secure the S3 bucket using Origin Access Control (OAC).
4. Block all public access to the S3 bucket.
5. Enable server-side encryption for objects stored in S3.
6. Manage AWS infrastructure using Terraform.
7. Store Terraform state remotely in Amazon S3, using Terraform's native S3 lockfile for state locking.
8. Validate and plan Terraform changes automatically on every pull request, so a reviewer sees what will change before merging.
9. Apply changes on merge to `main`, behind a manual approval gate.
10. Authenticate all three workflows with short-lived OIDC credentials and separate IAM roles for plan and apply, with no static AWS access keys.

## Architecture

![Architecture Diagram](docs/terraform-portfolio-website.png)

## Prerequisites
-  Terraform CLI - https://developer.hashicorp.com/terraform/install
-  AWS CLI - https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
-  AWS Account with permissions to create S3, CloudFront, and IAM resources
-  Node.js and npm
-  GitHub repository variables named `AWS_PLAN_ROLE_ARN` and `AWS_APPLY_ROLE_ARN`, a GitHub Environment named `prod` with a required reviewer, and branch protection on `main` (see [Bootstrapping](#bootstrapping-the-remote-backend-and-pipeline-roles) below) if you want the workflows to run

## CI/CD Pipeline
Terraform changes flow through three GitHub Actions workflows. All three filter on `terraform/**`, so a change elsewhere in the repository doesn't burn a runner.

**1. Validate** — runs on pull requests, checks the config without touching AWS:
1. Checks Terraform formatting (`terraform fmt -check`)
2. Initializes Terraform without the remote backend (`terraform init -backend=false`)
3. Validates the configuration (`terraform validate`)

See the full writeup: [Infrastructure Delivery with GitHub Actions: Part 1](https://medium.com/@samiashafique/production-style-infrastructure-delivery-with-github-actions-part-1-validating-terraform-changes-bd9649f9704a).

**2. Plan** — runs on pull requests, shows the reviewer exactly what will change in AWS before the PR merges:
1. Assumes a read-only IAM role via GitHub OIDC (short-lived credentials, no stored secrets)
2. Initializes Terraform against the real S3 backend
3. Runs `terraform plan` and posts the result as a comment on the pull request, updating the same comment on subsequent pushes

See the full writeup: [Infrastructure Delivery with GitHub Actions: Part 2](https://medium.com/@samiashafique/infrastructure-delivery-with-github-actions-part-2-planning-terraform-changes-on-every-pull-fdbb8b5e91ad).

**3. Apply** — runs on merge to `main`, applies the change to AWS after a human approves:
1. Pauses at the `prod` GitHub Environment until a required reviewer approves. Nothing runs before that point. No checkout, no token, no credentials
2. Assumes a separate apply role via OIDC, distinct from the plan role and holding write permissions the plan role does not have
3. Runs `terraform apply -auto-approve` against the real backend

Plan and apply use separate roles on purpose. A single role would need one trust policy admitting both triggers, which would give the `pull_request` trigger, running code a contributor controls, the permissions that change infrastructure. The apply role's trust policy pins the token audience, the `prod` environment and the `main` branch, and all three must match before AWS issues credentials. Part 3 of the article series covers the reasoning.

See the full write up: [Infrastructure Delivery with GitHub Actions: Part 3](https://medium.com/@samiashafique/infrastructure-delivery-with-github-actions-part-3-applying-terraform-changes-on-merge-to-main-d843bc20023a?postPublishedType=initial)

**What this pipeline does not do.** It manages infrastructure, not content. The website files still reach S3 through `aws s3 sync` run by hand, so tearing the stack down and rebuilding it restores the bucket and the distribution but not the site. Automating that needs its own workflow and its own role. See [Future Improvements](#future-improvements).

## Bootstrapping the Remote Backend and Pipeline Roles
Before initializing Terraform, create the remote backend that stores the Terraform state, and the two IAM roles the workflows assume via OIDC. Both are chicken-and-egg problems, since the pipeline can't create the roles it needs in order to run, so this part is applied manually, once, from your machine.

Keeping it manual is a choice. A pipeline that could edit its own IAM would be able to widen its own permissions, and the approval gate would mean nothing.

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

State locking uses Terraform's native S3 lockfile support (`use_lockfile = true`), so no DynamoDB table is required.

### 4. Apply the bootstrap config
This creates the GitHub OIDC provider, the plan-only role (`bootstrap/plan-role.tf`) and the apply role (`bootstrap/apply-role.tf`):
```bash
cd bootstrap
terraform init
terraform apply
```

### 5. Configure the GitHub repository variables
Copy the role ARNs from the bootstrap apply and add them as repository variables so the workflows can assume them:
```bash
terraform output plan_role_arn
terraform output apply_role_arn
```
In GitHub: **Settings → Secrets and variables → Actions → Variables** → add `AWS_PLAN_ROLE_ARN` and `AWS_APPLY_ROLE_ARN` with those values.

These are variables rather than secrets because a role ARN is an identifier, not a credential. The trust policy is what controls access to the role.

### 6. Create the `prod` environment
In GitHub: **Settings → Environments** → create an environment named exactly `prod` and add yourself as a required reviewer.

This is what pauses the apply workflow and fulfills the requirement of manually approving before applying.

### 7. Protect the `main` branch
In GitHub: **Settings → Rules → Rulesets** → require a pull request before merging to `main`.

Without this, a direct push to `main` triggers the apply workflow having skipped validation and plan entirely.

Once the backend resources exist and both roles are bootstrapped, update the S3 bucket name in `terraform/backend.tf` to match the bucket you created above. You can then continue with the deployment steps below.

## Steps to Deploy
These steps stand the project up the first time, from a machine with credentials. Once it is running, changes under `terraform/` go through a pull request and are applied by the pipeline on merge. See [CI/CD Pipeline](#cicd-pipeline).

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

This upload step stays manual. Terraform manages the bucket, not its contents, so the site has to be published separately after the infrastructure exists.

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
- Short-lived OIDC credentials for every workflow, so no static AWS access keys are stored in GitHub
- Separate IAM roles for plan and apply, so the trigger that runs contributor-controlled code cannot reach the permissions that change infrastructure
- Plan role restricted to read-only plus a single-object S3 lock permission, with no write access to actual infrastructure
- Apply role trust policy pins token audience, `prod` environment and `main` branch, all three required
- Apply role write permissions scoped by ARN wherever AWS supports it: bucket-level actions on the website bucket only, object writes limited to the two Terraform state keys, and delete limited to the lock file
- IAM roles managed in a separate bootstrap configuration the pipeline cannot apply, so it cannot grant itself permissions

## Future Improvements
* Automate the content deploy (build, `aws s3 sync` and CloudFront invalidation) in its own workflow with its own role, scoped to bucket objects and invalidations and holding no infrastructure permissions
* Scope the plan and apply roles' read permissions from the actual API calls Terraform makes, instead of the broad `ReadOnlyAccess` managed policy currently attached to each
* Extend the validation workflow's `terraform/**` path filter to also cover `bootstrap/`. The most privileged configuration in the repository is currently the one the pipeline never checks
* Adopt GitHub's immutable OIDC subject claims. This repository predates the 15 July 2026 default, so it still uses the name-based `sub` format; renaming or transferring the repository would switch it over and break both trust policies
* Refactor the configuration to use input variables instead of hardcoded values

