variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "s3_bucket_name" {
  description = "S3 bucket name to store Lambda artifacts"
  type        = string
}

variable "lambda_role_name" {
  description = "Name for the Lambda IAM role"
  type        = string
  default     = "envioclick_lambda_role"
}
