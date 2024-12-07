import boto3
import os

def handler(event, context):
    cloudwatch = boto3.client('cloudwatch')
    ec2 = boto3.client('ec2')

    namespace = os.environ['CUSTOM_NAMESPACE']

    # Fetch EBS volumes
    volumes = ec2.describe_volumes()
    unattached_volumes = [vol for vol in volumes['Volumes'] if len(vol['Attachments']) == 0]
    unattached_volume_count = len(unattached_volumes)
    unattached_volume_size = sum(vol['Size'] for vol in unattached_volumes)

    # Fetch EBS snapshots
    snapshots = ec2.describe_snapshots(OwnerIds=['self'])
    unencrypted_snapshots = [snap for snap in snapshots['Snapshots'] if not snap['Encrypted']]
    unencrypted_snapshot_count = len(unencrypted_snapshots)

    # Fetch unencrypted volumes
    unencrypted_volumes = [vol for vol in volumes['Volumes'] if not vol['Encrypted']]
    unencrypted_volume_count = len(unencrypted_volumes)
    print(f'Unattached EBS volume count: {unattached_volume_count}')
    print(f'Unattached EBS volume size: {unattached_volume_size} GiB')
    print(f'Unencrypted EBS volume count: {unencrypted_volume_count}')
    print(f'Unencrypted snapshot count: {unencrypted_snapshot_count}')

    # Put metrics to CloudWatch
    cloudwatch.put_metric_data(
        Namespace=namespace,
        MetricData=[
            {
                'MetricName': 'UnattachedEBSVolumeCount',
                'Value': unattached_volume_count,
                'Unit': 'Count'
            },
            {
                'MetricName': 'UnattachedEBSVolumeSize',
                'Value': unattached_volume_size,
                'Unit': 'Gigabytes'
            },
            {
                'MetricName': 'UnencryptedEBSVolumeCount',
                'Value': unencrypted_volume_count,
                'Unit': 'Count'
            },
            {
                'MetricName': 'UnencryptedSnapshotCount',
                'Value': unencrypted_snapshot_count,
                'Unit': 'Count'
            }
        ]
    )
    return {
        'statusCode': 200,
        'body': 'Metrics collected and published to CloudWatch'
    }
