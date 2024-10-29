#!/bin/bash
yum update -y
yum install -y stress-ng
yum install -y amazon-cloudwatch-agent
cat <<EOT > /opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-agent-config.json
{
    "metrics": {
    "metrics_collected": {
        "cpu": {
        "measurement": [
            {"name": "cpu_usage_idle", "rename": "CPUUsageIdle", "unit": "Percent"},
            {"name": "cpu_usage_user", "rename": "CPUUsageUser", "unit": "Percent"},
            {"name": "cpu_usage_system", "rename": "CPUUsageSystem", "unit": "Percent"},
            {"name": "cpu_usage_active", "rename": "CPUUtilization", "unit": "Percent"}
        ],
        "metrics_collection_interval": 30
        }
    }
    }
}
EOT
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-agent-config.json \
    -s
systemctl start amazon-cloudwatch-agent
systemctl enable amazon-cloudwatch-agent