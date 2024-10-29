# CloudWatch Log Group for S3 Bucket Logging
resource "aws_cloudwatch_log_group" "s3_bucket_log_group" {
  name              = "/aws/s3/bucket-logs"
  retention_in_days = 1
}

# S3 Bucket for CloudTrail Logs
resource "aws_s3_bucket" "cloudtrail_logs_bucket" {
  bucket = "cloudtrail-logs-bucket-32332131231" 
  force_destroy = true
}

# S3 Bucket Policy for CloudTrail Logs Bucket
resource "aws_s3_bucket_policy" "cloudtrail_logs_bucket_policy" {
  bucket = aws_s3_bucket.cloudtrail_logs_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Action = "s3:GetBucketAcl",
        Resource = "arn:aws:s3:::${aws_s3_bucket.cloudtrail_logs_bucket.id}"
      },
      {
        Effect = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Action = "s3:PutObject",
        Resource = "arn:aws:s3:::${aws_s3_bucket.cloudtrail_logs_bucket.id}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

# CloudTrail for Monitoring All S3 Buckets
resource "aws_cloudtrail" "s3_bucket_monitoring" {
  name                          = "s3-bucket-monitoring-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs_bucket.bucket
  include_global_service_events = true
  is_multi_region_trail         = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"]
    }
  }

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.s3_bucket_log_group.arn}:*"
  cloud_watch_logs_role_arn   = aws_iam_role.cloudtrail_role.arn
}

# IAM Role for CloudTrail
resource "aws_iam_role" "cloudtrail_role" {
  name = "cloudtrail-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for CloudTrail to Write Logs to CloudWatch
resource "aws_iam_role_policy" "cloudtrail_policy" {
  name = "cloudtrail-policy"
  role = aws_iam_role.cloudtrail_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "${aws_cloudwatch_log_group.s3_bucket_log_group.arn}:*"
      }
    ]
  })
}

# CloudWatch Metric Filter for GetObject
resource "aws_cloudwatch_log_metric_filter" "get_object_filter" {
  name           = "GetObjectFilter"
  log_group_name = aws_cloudwatch_log_group.s3_bucket_log_group.name
  pattern        = "{ ($.eventName = GetObject) }"

  metric_transformation {
    name      = "GetObjectCount"
    namespace = "S3Operations"
    value     = "1"
  }
}

# CloudWatch Metric Filter for PutObject
resource "aws_cloudwatch_log_metric_filter" "put_object_filter" {
  name           = "PutObjectFilter"
  log_group_name = aws_cloudwatch_log_group.s3_bucket_log_group.name
  pattern        = "{ ($.eventName = PutObject) }"

  metric_transformation {
    name      = "PutObjectCount"
    namespace = "S3Operations"
    value     = "1"
  }
}

# CloudWatch Metric Filter for DeleteObject
resource "aws_cloudwatch_log_metric_filter" "delete_object_filter" {
  name           = "DeleteObjectFilter"
  log_group_name = aws_cloudwatch_log_group.s3_bucket_log_group.name
  pattern        = "{ ($.eventName = DeleteObject) }"

  metric_transformation {
    name      = "DeleteObjectCount"
    namespace = "S3Operations"
    value     = "1"
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "s3_operations_dashboard" {
  dashboard_name = "S3OperationsDashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric",
        x    = 0,
        y    = 0,
        width = 24,
        height = 6,
        properties = {
          metrics = [
            [ "S3Operations", "GetObjectCount" ],
            [ "S3Operations", "PutObjectCount" ],
            [ "S3Operations", "DeleteObjectCount" ]
          ],
          period = 300,
          stat   = "Sum",
          region = "us-east-1",
          title  = "S3 Operations Count"
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "important-bucket" {
  bucket        = "important-bucket-232trt4t"
  force_destroy = true
}