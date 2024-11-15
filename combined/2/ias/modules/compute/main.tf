# ECS Cluster with Container Insights enabled
resource "aws_ecs_cluster" "this" {
  name = "${var.app_name}-ecs-cluster-${var.env}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = {
    environment = var.env
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.app_name}-ecs-task-execution-role-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
}

resource "aws_iam_policy" "ecs_task_execution_role_policy" {
  name = "${var.app_name}-ecs-task-execution-policy-${var.env}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Effect   = "Allow"
        Resource = var.db_secrets_arn
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_task_execution_role_policy.arn
  depends_on = [ aws_iam_policy.ecs_task_execution_role_policy ]
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.app_name}-ecs-task-role-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_task_policy" {
  name = "${var.app_name}-ecs-task-policy-${var.env}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_policy.arn
}

# ECS Task Definition
resource "aws_ecs_task_definition" "this" {
  family                   = "${var.app_name}-task-family-${var.env}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name = "${var.app_name}-container-${var.env}"
      image = var.app_image_id
      essential = true
      portMappings = [
        {
          containerPort = var.app_container_port
          hostPort      = var.app_container_port
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost/health || exit 1"]
        interval    = 30
        timeout     = 5
        startPeriod = 10
        retries     = 3
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-create-group": "true",
          "awslogs-group"         = "/ecs/${var.app_name}-${var.env}",
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs-${var.app_name}-${var.env}"
        }
      }
      environment = [
        {
          name  = "DB_HOST"
          value = var.db_instance_address
        },
        {
          name  = "DB_PORT"
          value = tostring(var.db_port)
        }
      ]
      secrets = [
        {
          name      = "DB_SECRETS"
          valueFrom = var.db_secrets_arn
        }
      ]
    }
  ])
  tags = {
    environment = var.env
  }
}

# ECS Service
resource "aws_ecs_service" "this" {
  name            = "${var.app_name}-ecs-service-${var.env}"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnets
    assign_public_ip = false
    security_groups  = [aws_security_group.ecs_sg.id]
  }

  load_balancer {
    target_group_arn = var.lb_target_group_arn
    container_name   = "${var.app_name}-container-${var.env}"
    container_port   = var.app_container_port
  }

  depends_on = [var.alb_sg_id]

  tags = {
    environment = var.env
  }
}

# Security Group for ECS
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-security-group"
  description = "Allow traffic from ALB to ECS"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = var.app_container_port
    to_port         = var.app_container_port
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role_policy_attachment" "ecs_cloudwatch_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}


# IAM assume Role
resource "aws_iam_role" "ec2_assume_role" {
  name = "ec2_assume_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com",
        },
      },
    ],
  })
}


# Attach SSM policy to role
resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  role       = aws_iam_role.ec2_assume_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2.instance_profile"
  role = aws_iam_role.ec2_assume_role.name
}


resource "aws_security_group" "jump_host" {
  vpc_id = var.vpc_id
  description = "Jump host security group"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    environment = var.env
  }
}

module "jump_host" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.1"

  name                        = "jumphost"
  ami                         = "ami-0738e1a0d363b9c7e"
  instance_type               = "t2.micro"
  subnet_id                   = var.subnets[0]
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
  vpc_security_group_ids      = [aws_security_group.jump_host.id]

  tags = {
    environment = var.env
  }
}
