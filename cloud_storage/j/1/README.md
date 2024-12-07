
Enable MFA for primary bucket.
```shell
aws s3api put-bucket-versioning --region <REGION> \
--bucket <BUCKET NAME> \
--versioning-configuration Status=Enabled,MFADelete=Enabled \
--mfa "arn:aws:iam::<ACCOUNT ID>:mfa/root-account-mfa-device <MFA CODE>"
```