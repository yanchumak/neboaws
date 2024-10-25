locals {
  name     = "my-vpc"
  vpc_cidr = "10.0.0.0/16"
  azs      = ["us-east-1a", "us-east-1b"]
  az_count = length(local.azs)
}

# Use a public VPC module to create a VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.14.0"

  name = local.name
  cidr = local.vpc_cidr

  azs              = local.azs
  public_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + local.az_count)]
  database_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 2 * local.az_count)]

  create_database_subnet_group = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_security_group" "rds_sg" {
  vpc_id = module.vpc.vpc_id
  name   = "rds-sg"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}


# Create RDS inside VPC (PostgreSQL)
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.10.0"

  identifier = "my-rds-instance"

  engine               = "postgres"
  engine_version       = "14"
  family               = "postgres14" # DB parameter group
  major_engine_version = "14"         # DB option group

  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp2"
  username          = var.db_username
  password          = var.db_password
  manage_master_user_password = false

  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible = false

  maintenance_window  = "Mon:00:00-Mon:03:00"
  skip_final_snapshot = true

  tags = {
    Name = "rds-instance"
  }
}


# Create an IAM role and policy for the Lambda to access RDS and CloudWatch
resource "aws_iam_role" "lambda_execution" {
  name = "lambda-vpc-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda-vpc-access-policy"
  description = "Allow Lambda to access VPC, RDS, and CloudWatch"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "rds:*",
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "logs:*",
          "cloudwatch:*"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_policy" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}


# Lambda function inside VPC
resource "aws_lambda_function" "vpc_lambda" {
  filename      = "lambda_function.zip" # This will be the zipped Python file
  function_name = "vpc-lambda-function"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"

  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.rds_sg.id]
  }

  lifecycle {
    create_before_destroy = true
  }

  environment {
    variables = {
      DB_ENDPOINT = module.rds.db_instance_address
      DB_PORT     = "5432"
      DB_USER     = var.db_username
      DB_PASSWORD = var.db_password
    }
  }

  tags = {
    Name = "vpc-lambda-function"
  }

  # Ensure that we recreate the function when the IAM role changes
  depends_on = [aws_iam_role_policy_attachment.lambda_vpc_policy]
}

# CloudWatch log group for Lambda
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/vpc-lambda-function"
  retention_in_days = 14
}

# CloudWatch Dashboard - reference the external JSON file
resource "aws_cloudwatch_dashboard" "lambda_rds_dashboard" {
  dashboard_name = "lambda-rds-dashboard"

  dashboard_body = file("${path.module}/cloudwatch_dashboard.json")
}

# CloudWatch EventBridge (Cron) to invoke Lambda every hour to keep warm
resource "aws_cloudwatch_event_rule" "cron_lambda_invocation" {
  name                = "lambda-scheduled-cron"
  description         = "Trigger Lambda every hour"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "lambda_cron_target" {
  rule      = aws_cloudwatch_event_rule.cron_lambda_invocation.name
  target_id = "lambda"
  arn       = aws_lambda_function.vpc_lambda.arn
}

# Permission for EventBridge to invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge_to_invoke_lambda" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.vpc_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cron_lambda_invocation.arn
}
