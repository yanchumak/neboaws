#!/bin/bash

# Install nginx
apt-get install -y nginx
systemctl start nginx
systemctl enable nginx
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`

# Output instance ID to web server
echo "Instance ID: $(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)" > /var/www/html/index.html