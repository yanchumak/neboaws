import boto3
import logging
from botocore.exceptions import NoCredentialsError, PartialCredentialsError

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def list_s3_buckets():
    """Lists all S3 buckets for the current AWS account."""
    try:
        s3_client = boto3.client("s3")        
        response = s3_client.list_buckets()
        buckets = response.get("Buckets", [])

        logger.info(f"Successfully retrieved {len(buckets)} buckets.")
        for bucket in buckets:
            logger.info(f"Bucket: {bucket['Name']} - Created: {bucket['CreationDate']}")

    except NoCredentialsError:
        logger.error("AWS credentials not found. Ensure they are configured.")
    except PartialCredentialsError:
        logger.error("Incomplete AWS credentials. Check your configuration.")
    except Exception as e:
        logger.error(f"An error occurred: {str(e)}", exc_info=True)


if __name__ == "__main__":
    list_s3_buckets()
