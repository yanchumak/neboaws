## Put RDS secret
```shell
 aws secretsmanager create-secret --name rds_credentials --secret-string '{\"username\":\"RDS_USERNAME\",\"password\":\"RDS_PASSWORD\"}'
```
