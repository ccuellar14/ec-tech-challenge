# 04-cloud-lab - AWS deployment with Terraform

This folder contains a minimal AWS Lambda app and Terraform infra to deploy it.

Files added:
- `infra/` - Terraform config (S3 bucket + IAM role)
- `.github/workflows/deploy.yml` - CI workflow that runs Terraform, packages the Lambda, uploads to S3 and creates/updates the Lambda
- `scripts/deploy_local.sh` - helper script for local deploy

Secrets required for CI (set in GitHub repository secrets):
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

Usage (local):

```bash
# export AWS_REGION, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
chmod +x scripts/deploy_local.sh
scripts/deploy_local.sh
```

The workflow will create an S3 bucket (name constructed from repository owner + run number), an IAM role for Lambda and then upload the function package.
