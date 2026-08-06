# Portfolio Website Deployment
![Terraform Validation](https://github.com/samiashafique/terraform-portfolio-project/actions/workflows/validate.yml/badge.svg)
This repository contains the Terraform code to deploy a static Next.js portfolio website on AWS using modern Infrastructure as Code (IaC) and security best practices.
📄 Read the full writeup: [Deploying a Next.js Portfolio with Terraform, S3, and CloudFront](https://medium.com/@samiashafique/from-project-brief-to-production-style-infrastructure-deploying-a-next-js-908f305a6253)

## Project Overview
A freelance web designer required a secure, scalable, and cost-effective solution to host their modern single-page portfolio website built with Next.js. This project demonstrates how to:
1. Deploy a static Next.js website using Amazon S3.
2. Deliver content globally with Amazon CloudFront.
3. Secure the S3 bucket using Origin Access Control (OAC).
4. Block all public access to the S3 bucket.
5. Enable server-side encryption for objects stored in S3.
6. Manage AWS infrastructure using Terraform.
7. Store Terraform state remotely in Amazon S3 with DynamoDB state locking.

## Architecture

 <img width="701" height="691" alt="image" src="https://github.com/user-attachments/assets/3b37c064-f892-4ad6-916f-b12bde93ff2a" />

## Prerequisites
-  Terraform CLI - https://developer.hashicorp.com/terraform/install
-  AWS CLI - https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
-  AWS Account with permissions to create S3, CloudFront, IAM and DynamoDB resources
-  Node.js and npm

## CI/CD Pipeline
Terraform changes are validated automatically before code review using GitHub Actions.
On every pull request that touches the `terraform/` directory, the workflow:
1. Checks Terraform formatting (`terraform fmt -check`)
2. Initializes Terraform without the remote backend (`terraform init -backend=false`)
3. Validates the configuration (`terraform validate`)

This catches formatting and syntax errors before a human reviewer looks at the change. See the full writeup: [Infrastructure Delivery with GitHub Actions: Part 1](https://medium.com/@samiashafique/production-style-infrastructure-delivery-with-github-actions-part-1-validating-terraform-changes-bd9649f9704a).

*More stages (plan-on-PR, plan-approval-gated apply) are covered in later parts of this series.*

## Bootstrapping the Remote Backend
Before initializing Terraform, create the remote backend that will store the Terraform state file and provide state locking.

> **Note:** This project uses the **Canada (Central) (`ca-central-1`)** AWS Region. Replace `your-unique-backend-bucket-name` with a globally unique S3 bucket name and update `backend.tf` accordingly.

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

### 4. Create the DynamoDB table for state locking
```bash
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ca-central-1
```

Once the backend resources have been created, update the S3 bucket name in `terraform/backend.tf` to match the bucket you created above. You can then continue with the deployment steps below.

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
- Remote Terraform state with state locking

## Future Improvements
* Add a `terraform plan` workflow on pull requests so reviewers can see exactly what will change before merging (in progress — see Part 2 of the article series)
* Replace DynamoDB state locking with Terraform's native S3 lockfile support (`use_lockfile`)
* Refactor the configuration to use input variables instead of hardcoded values

