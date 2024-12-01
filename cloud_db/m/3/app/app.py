from typing import Tuple, Union
from urllib.parse import ParseResult, urlencode, urlunparse

import botocore.session
import redis
from botocore.model import ServiceId
from botocore.signers import RequestSigner
import argparse

parser = argparse.ArgumentParser(description='Test elasticache integration') 
parser.add_argument("--port", type=int, default=6379)
parser.add_argument("--host", type=str, default="localhost")
parser.add_argument("--user", type=str, default="default")
parser.add_argument("--cluster", type=str)
args = parser.parse_args()

class ElastiCacheIAMProvider(redis.CredentialProvider):
    def __init__(self, user, cluster_name, region="us-east-1"):
        self.user = user
        self.cluster_name = cluster_name
        self.region = region

        session = botocore.session.get_session()
        self.request_signer = RequestSigner(
            ServiceId("elasticache"),
            self.region,
            "elasticache",
            "v4",
            session.get_credentials(),
            session.get_component("event_emitter"),
        )

    def get_credentials(self) -> Union[Tuple[str], Tuple[str, str]]:
        query_params = {"Action": "connect", "User": self.user}
        url = urlunparse(
            ParseResult(
                scheme="https",
                netloc=self.cluster_name,
                path="/",
                query=urlencode(query_params),
                params="",
                fragment="",
            )
        )
        signed_url = self.request_signer.generate_presigned_url(
            {"method": "GET", "url": url, "body": {}, "headers": {}, "context": {}},
            operation_name="connect",
            expires_in=900,
            region_name=self.region,
        )

        # Elasticache only accepts the URL without a protocol
        return (self.user, signed_url.removeprefix("https://"))

creds_provider = ElastiCacheIAMProvider(user=args.user, cluster_name=args.cluster)
conn = redis.Redis(host=args.host, port=args.port, ssl=True, credential_provider=creds_provider)
conn.ping()
print('Connected to Redis')
conn.set('foo', 'bar')
val = conn.get('foo')
print('Got value from Redis:', val)

