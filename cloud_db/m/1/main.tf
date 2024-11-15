# Create DynamoDB Table
resource "aws_dynamodb_table" "my_table" {
  name           = "MyDynamoDBTable"
  billing_mode   = "PAY_PER_REQUEST" # On-demand pricing
  hash_key       = "PK"              # Partition key
  range_key      = "SK"              # Sort key

  attribute {
    name = "PK"
    type = "S" # String
  }

  attribute {
    name = "SK"
    type = "S" # String
  }

  # Define Global Secondary Index
  global_secondary_index {
    name               = "GSI1"   # Name of GSI
    hash_key           = "GSI_PK" # Partition key for GSI
    range_key          = "GSI_SK" # Sort key for GSI
    projection_type    = "ALL"    # Project all attributes
    
    # Provisioned read/write capacity (optional if PAY_PER_REQUEST)
    read_capacity  = 5
    write_capacity = 5
  }

  attribute {
    name = "GSI_PK"
    type = "S" # String
  }

  attribute {
    name = "GSI_SK"
    type = "S" # String
  }

  tags = {
    Name = "MyDynamoDBTable"
    Env  = "dev"
  }
}