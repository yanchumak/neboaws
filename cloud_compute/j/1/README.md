```shell
aws ec2 describe-images \
    --owners 099720109477 \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-*-*-amd64-server-*" \
    --query 'Images | sort_by(@, &CreationDate)[-1].ImageId' \
    --region us-east-1 \
    --output text

```