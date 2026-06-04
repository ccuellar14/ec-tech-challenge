#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)

if [ -z "${AWS_REGION:-}" ] || [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
  echo "Please export AWS_REGION, AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
  exit 1
fi

S3_BUCKET_NAME="${S3_BUCKET_NAME:-$(whoami)-envioclick-04cloudlab-local}"

echo "Initializing Terraform (infra)..."
cd "$ROOT_DIR/infra"
export TF_VAR_s3_bucket_name="$S3_BUCKET_NAME"
terraform init
terraform apply -auto-approve

echo "Packaging Lambda..."
cd "$ROOT_DIR"
zip -j lambda_function.zip main.py

echo "Uploading artifact to s3://$S3_BUCKET_NAME/..."
aws s3 cp lambda_function.zip s3://$S3_BUCKET_NAME/lambda_function.zip

ROLE_ARN=$(terraform output -raw lambda_role_arn)

echo "Creating/updating Lambda function..."
aws lambda get-function --function-name envioclick-04-cloud-lab >/dev/null 2>&1 || true
if aws lambda get-function --function-name envioclick-04-cloud-lab >/dev/null 2>&1; then
  aws lambda update-function-code --function-name envioclick-04-cloud-lab --s3-bucket $S3_BUCKET_NAME --s3-key lambda_function.zip
else
  aws lambda create-function --function-name envioclick-04-cloud-lab --runtime python3.11 --handler main.handler --role "$ROLE_ARN" --code S3Bucket=$S3_BUCKET_NAME,S3Key=lambda_function.zip
fi

echo "Done."
