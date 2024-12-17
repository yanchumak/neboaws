
resource "aws_ecs_task_definition" "ecs_task_definition" {
  depends_on = [
    aws_autoscaling_group.ecs
  ]
  family             = "ecs-cwagent-daemon-service"
  task_role_arn      = aws_iam_role.cwagent_ecs_task_role.arn
  execution_role_arn = aws_iam_role.cwagent_ecs_execution_role.arn
  network_mode       = "bridge"
  container_definitions = jsonencode([
    {
      name  = "cloudwatch-agent"
      image = "public.ecr.aws/cloudwatch-agent/cloudwatch-agent:1.300049.1b929"
      mountPoints = [
        {
          readOnly      = true
          containerPath = "/rootfs/proc"
          sourceVolume  = "proc"
        },
        {
          readOnly      = true
          containerPath = "/rootfs/dev"
          sourceVolume  = "dev"
        },
        {
          readOnly      = true
          containerPath = "/sys/fs/cgroup"
          sourceVolume  = "al2_cgroup"
        },
        {
          readOnly      = true
          containerPath = "/cgroup"
          sourceVolume  = "al1_cgroup"
        },
        {
          readOnly      = true
          containerPath = "/rootfs/sys/fs/cgroup"
          sourceVolume  = "al2_cgroup"
        },
        {
          readOnly      = true
          containerPath = "/rootfs/cgroup"
          sourceVolume  = "al1_cgroup"
        }
      ]
      environment = [
        {
          Name  = "USE_DEFAULT_CONFIG"
          Value = "True"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-create-group  = "True"
          awslogs-group         = "/ecs/ecs-cwagent-daemon-service"
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
  requires_compatibilities = [
    "EC2"
  ]
  volume {
    name      = "proc"
    host_path = "/proc"
  }

  volume {
    name      = "dev"
    host_path = "/dev"
  }

  volume {
    name      = "al1_cgroup"
    host_path = "/cgroup"
  }

  volume {
    name      = "al2_cgroup"
    host_path = "/sys/fs/cgroup"
  }

  cpu    = "128"
  memory = "64"
}

resource "aws_ecs_service" "cwagent_ecs_daemon_service" {
  task_definition     = aws_ecs_task_definition.ecs_task_definition.arn
  cluster             = aws_ecs_cluster.main.id
  launch_type         = "EC2"
  scheduling_strategy = "DAEMON"
  name                = "cwagent-daemon-service"
}

resource "aws_iam_role" "cwagent_ecs_task_role" {
  description        = "Allows ECS tasks to call AWS services on your behalf."
  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ecs-tasks.amazonaws.com"
        },
        "Effect": "Allow"
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy_attachment" "cwagent_ecs_task_policy" {
  role       = aws_iam_role.cwagent_ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role" "cwagent_ecs_execution_role" {
  description        = "Allows ECS container agent makes calls to the Amazon ECS API on your behalf."
  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ecs-tasks.amazonaws.com"
        },
        "Effect": "Allow"
      }
    ]
  }
  EOF
  name               = "CWAgentECSExecutionRole"
}

resource "aws_iam_role_policy_attachment" "cwagent_ecs_execution_policy_server_policy" {
  role       = aws_iam_role.cwagent_ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "cwagent_ecs_execution_policy_ecs_execution_role" {
  role       = aws_iam_role.cwagent_ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}