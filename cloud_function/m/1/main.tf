locals {
  az = "us-east-1a"
}

# Create IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_policy_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_policy"
  description = "IAM policy for Lambda to access CloudWatch and EBS"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}


data "archive_file" "python_lambda_package" {
  type        = "zip"
  source_file = "${path.module}/code/index.py"
  output_path = "lambda_function.zip"
}

# Lambda function
resource "aws_lambda_function" "collect_metrics" {
  filename         = "lambda_function.zip"
  function_name    = "collect_metrics_function"
  source_code_hash = data.archive_file.python_lambda_package.output_base64sha256
  role             = aws_iam_role.lambda_exec.arn
  timeout = 5
  handler          = "index.handler"
  runtime          = "python3.9"

  environment {
    variables = {
      CUSTOM_NAMESPACE = "CustomMetricsNamespace"
    }
  }
}

# EventBridge Rule to trigger Lambda
resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "daily_trigger"
  schedule_expression = "cron(0 0 * * ? *)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_trigger.name
  target_id = "lambda_target"
  arn       = aws_lambda_function.collect_metrics.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collect_metrics.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}

# Create an encrypted EBS volume
resource "aws_ebs_volume" "encrypted_volume" {
  availability_zone = local.az
  size              = 1
  encrypted         = true
  tags = {
    Name = "EncryptedEBSVolume"
  }
}

# Create a non-encrypted EBS volume
resource "aws_ebs_volume" "non_encrypted_volume" {
  availability_zone = local.az
  size              = 1
  encrypted         = false
  tags = {
    Name = "NonEncryptedEBSVolume"
  }
}

# Create a snapshot of the non-encrypted EBS volume
resource "aws_ebs_snapshot" "non_encrypted_snapshot" {
  volume_id = aws_ebs_volume.non_encrypted_volume.id
  tags = {
    Name = "NonEncryptedVolumeSnapshot"
  }
}
