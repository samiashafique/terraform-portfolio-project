# S3 bucket
resource "aws_s3_bucket" "portfolio" {
  bucket = "ss-portfolio-website-bucket"

  tags = {
    Name = "Portfolio Website"
  }
}

<<<<<<< Updated upstream
# S3 Bucket Static Website Configuration
resource "aws_s3_bucket_website_configuration" "website_configuration" {
=======
# S3 Bucket Ownership Control
resource "aws_s3_bucket_ownership_controls" "portfolio" {
  bucket = aws_s3_bucket.portfolio.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "portfolio" {
>>>>>>> Stashed changes
  bucket = aws_s3_bucket.portfolio.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

<<<<<<< Updated upstream
# S3 Bucket Policy
resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.portfolio.id
  policy = data.aws_iam_policy_document.website_policy.json
}

#IAM Policy Document
data "aws_iam_policy_document" "website_policy" {
  statement {
    sid    = "PublicReadGetObject"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
=======
# IAM Policy Document
data "aws_iam_policy_document" "website_policy" {

  statement {

    sid    = "AllowCloudFrontServicePrincipal"
    effect = "Allow"

    principals {
      type = "Service"

      identifiers = [
        "cloudfront.amazonaws.com"
      ]
>>>>>>> Stashed changes
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.portfolio.arn}/*"
    ]
<<<<<<< Updated upstream
  }
=======

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"

      values = [
        aws_cloudfront_distribution.website_distribution.arn
      ]
    }
  }
}
# S3 Bucket Policy
resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.portfolio.id
  policy = data.aws_iam_policy_document.website_policy.json
}

# Origin Access Control (OAC)
resource "aws_cloudfront_origin_access_control" "portfolio_oac" {
  name                              = "portfolio-oac"
  description                       = "Origin Access Control for Portfolio Website"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
>>>>>>> Stashed changes
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "website_distribution" {

  origin {
    domain_name = aws_s3_bucket_website_configuration.website_configuration.website_endpoint
    origin_id   = "S3-Website"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {

    target_origin_id = "S3-Website"

    allowed_methods = [
      "GET",
      "HEAD"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    forwarded_values {

      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
 
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "Portfolio CloudFront"
  }
<<<<<<< Updated upstream
}
=======
}
>>>>>>> Stashed changes
