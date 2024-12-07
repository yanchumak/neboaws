# Create an S3 bucket with necessary configurations
resource "aws_s3_bucket" "primary" {
  bucket = "bucketprimiary123"

  tags = {
    Name        = "MyS3Bucket"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id

  versioning_configuration {
    status = "Enabled"
    #mfa_delete = "Enabled" should be enabled via AWS CLI
  }
}

resource "aws_s3_bucket_object_lock_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id

  object_lock_enabled = "Enabled"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" 
    }
  }
}

resource "aws_s3_bucket_public_access_block" "primary" {
  bucket                = aws_s3_bucket.primary.bucket
  block_public_acls     = true
  block_public_policy   = true
  ignore_public_acls    = true
  restrict_public_buckets = true
}

# Create an S3 Gateway VPC Endpoint
resource "aws_vpc_endpoint" "primary" {
  vpc_id       = aws_vpc.main_vpc_us_east.id
  service_name = "com.amazonaws.us-east-1.s3"
}

# Create IAM Users
resource "aws_iam_user" "readonly_user" {
  name = "ReadOnlyUser"
}

resource "aws_iam_user_login_profile" "readonly_user_profile" {
  user    = aws_iam_user.readonly_user.name
  password_length = 20
  password_reset_required = false
}

resource "aws_iam_user" "readwrite_user" {
  name = "ReadWriteUser"
}

resource "aws_iam_user_login_profile" "readwrite_user_profile" {
  user    = aws_iam_user.readwrite_user.name
  password_length = 20
  password_reset_required = false
}


resource "aws_iam_policy" "readonly_policy" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = "s3:ListAllMyBuckets",
        Resource = "arn:aws:s3:::*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket"
        ],
        Resource = "${aws_s3_bucket.primary.arn}"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
        ]
        Resource = [
          "${aws_s3_bucket.primary.arn}/*",
        ]
      },
    ]
  })
}


resource "aws_iam_policy" "readwrite_policy" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = "s3:ListAllMyBuckets",
        Resource = "arn:aws:s3:::*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket"
        ],
        Resource = "${aws_s3_bucket.primary.arn}"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
        ]
        Resource = [
          "${aws_s3_bucket.primary.arn}/*",
        ]
      },
    ]
  })
}

# Attach IAM Roles to the Users
resource "aws_iam_user_policy_attachment" "readonly_user_attach" {
  user       = aws_iam_user.readonly_user.name
  policy_arn = aws_iam_policy.readonly_policy.arn
}

resource "aws_iam_user_policy_attachment" "readwrite_user_attach" {
  user       = aws_iam_user.readwrite_user.name
  policy_arn = aws_iam_policy.readwrite_policy.arn
}

# Replication
resource "aws_iam_role" "replication_role" {
  name = "s3_replication_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "replication_policy" {
  name = "s3_replication_policy"
  role = aws_iam_role.replication_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:Get*",
          "s3:ListBucket"
        ],
        Effect = "Allow",
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.primary.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.primary.bucket}/*"
        ]
      },
      {
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
          "s3:GetObjectVersionTagging"
        ],
        Effect = "Allow",
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.replica.bucket}/*"
        ]
      }
    ]
  })
}

# Create the destination bucket in another region
resource "aws_s3_bucket" "replica" {
  provider = aws.us_west
  bucket = "replica125767"
}


resource "aws_s3_bucket_versioning" "replica" {
  provider = aws.us_west
  bucket = aws_s3_bucket.replica.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_replication_configuration" "replication" {
  bucket = aws_s3_bucket.primary.id
  role   = aws_iam_role.replication_role.arn

  rule {
    id     = "replication-rule"
    status = "Enabled"

    filter {
      prefix = ""
    }

    destination {
      bucket        = aws_s3_bucket.replica.arn
      storage_class = "STANDARD" 
    }

    delete_marker_replication {
      status = "Enabled"
    }
  }
  depends_on = [ 
    aws_s3_bucket_versioning.primary,
    aws_s3_bucket_versioning.replica 
  ]
}

