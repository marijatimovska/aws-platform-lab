# S3 bucket serving static content via S3 static website hosting.
# Objects are public-read ON PURPOSE - this bucket serves a public website.
# (In a real production setup you would put CloudFront + Origin Access Control
# in front and keep the bucket private; noted in docs/BREAK-IT-LAB.md as an upgrade.)

resource "aws_s3_bucket" "static" {
  bucket        = var.bucket_name
  force_destroy = true # lab: allow destroy even with objects inside
}

resource "aws_s3_bucket_website_configuration" "static" {
  bucket = aws_s3_bucket.static.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_public_access_block" "static" {
  bucket                  = aws_s3_bucket.static.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

data "aws_iam_policy_document" "public_read" {
  statement {
    sid       = "PublicReadGetObject"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.static.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.static.id
  policy = data.aws_iam_policy_document.public_read.json

  depends_on = [aws_s3_bucket_public_access_block.static]
}
