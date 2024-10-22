1. Inserting Data into the Table

```shell
aws dynamodb put-item \
    --table-name MyDynamoDBTable \
    --item '{
        "PK": {"S": "User#123"},
        "SK": {"S": "Profile"},
        "GSI_PK": {"S": "Email#user@example.com"},
        "GSI_SK": {"S": "2024-01-01"},
        "Name": {"S": "John Doe"},
        "Age": {"N": "30"}
    }'
```

2. Querying Data from the Global Secondary Index (GSI)

```shell
aws dynamodb query \
    --table-name MyDynamoDBTable \
    --index-name GSI1 \
    --key-condition-expression "GSI_PK = :email and GSI_SK = :date" \
    --expression-attribute-values '{
        ":email": {"S": "Email#user@example.com"},
        ":date": {"S": "2024-01-01"}
    }'
```

3. Querying Data from the Table (Using Primary Key)
```shell
aws dynamodb query \
    --table-name MyDynamoDBTable \
    --key-condition-expression "PK = :pk and SK = :sk" \
    --expression-attribute-values '{
        ":pk": {"S": "User#123"},
        ":sk": {"S": "Profile"}
    }'
```

4. Updating Data in the Table

```shell
aws dynamodb update-item \
    --table-name MyDynamoDBTable \
    --key '{
        "PK": {"S": "User#123"},
        "SK": {"S": "Profile"}
    }' \
    --update-expression "SET Age = :age" \
    --expression-attribute-values '{
        ":age": {"N": "31"}
    }'
```