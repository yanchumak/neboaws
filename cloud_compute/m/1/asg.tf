resource "aws_autoscaling_group" "this" {
  desired_capacity     = 1
  max_size             = 6
  min_size             = 1
  default_instance_warmup= 30
  launch_template {
    id      = aws_launch_template.app_template.id
    version = "$Latest"
  }

  target_group_arns    = []
  vpc_zone_identifier  = [aws_subnet.private_subnet_az1.id]

  tag {
    key                 = "Name"
    value               = "example-instance"
    propagate_at_launch = true
  }
}

# Step Scaling Policy
resource "aws_autoscaling_policy" "step_scale_out" {
  name                   = "step-scale-out"
  policy_type            = "StepScaling"
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.this.name

  step_adjustment {
    scaling_adjustment = 2  
    metric_interval_lower_bound = 0
    metric_interval_upper_bound = 20
  }

  step_adjustment {
    scaling_adjustment = 1  
    metric_interval_lower_bound = 20
  }
}

resource "aws_cloudwatch_metric_alarm" "high_cpu_step" {
  alarm_name          = "high-cpu-step"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 30
  statistic           = "Average"
  threshold           = 60

  alarm_actions = [aws_autoscaling_policy.step_scale_out.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }
}

# Simple Scaling Policy
resource "aws_autoscaling_policy" "simple_scale_in" {
  name                   = "simple-scale-in"
  scaling_adjustment     = -1  # Decrease by 1 instance
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.this.name
}

resource "aws_cloudwatch_metric_alarm" "low_cpu_simple" {
  alarm_name          = "low-cpu-simple"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 30
  statistic           = "Average"
  threshold           = 30  # Threshold for scaling in

  alarm_actions = [aws_autoscaling_policy.simple_scale_in.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }
}

# Scheduled Action
resource "aws_autoscaling_schedule" "scale_out_morning" {
  scheduled_action_name  = "scale-out-morning"
  min_size               = 3
  max_size               = 6
  desired_capacity       = 3
  recurrence             = "0 9 * * 1-5" # Cron expression for 09:00 on weekdays
  autoscaling_group_name = aws_autoscaling_group.this.name
}
