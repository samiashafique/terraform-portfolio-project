output "cloudfront_url" {
  value       = aws_cloudfront_distribution.website_distribution.domain_name
  description = "CloudFront domain name serving the website"
}

output "website_bucket_name" {
  value       = aws_s3_bucket.portfolio.id
  description = "S3 bucket holding the website files, for the deploy step to upload into"
}
