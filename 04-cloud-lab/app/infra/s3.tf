resource "aws_s3_bucket" "lambda_bucket" {
  bucket = var.s3_bucket_name

  lifecycle_rule {
    id      = "cleanup"
    enabled = true

    expiration {
      days = 30
    }
  }

  tags = {
    Name = "envioclick-lambda-artifacts"
  }
}
