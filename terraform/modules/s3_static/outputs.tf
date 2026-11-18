output "bucket_name" {
  value = aws_s3_bucket.static.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.static.arn
}

output "website_endpoint" {
  value = aws_s3_bucket_website_configuration.static.website_endpoint
}

output "website_url" {
  value = "http://${aws_s3_bucket_website_configuration.static.website_endpoint}"
}
