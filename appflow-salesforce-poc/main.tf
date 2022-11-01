terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "4.28.0"
    }
  }
}

provider "aws" {
    profile = "mockService"
    region  = "us-east-1"

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
}

resource "aws_s3_bucket" "salesforce-target" {
  bucket = "salesforce-target"
}

resource "aws_s3_bucket_policy" "salesforce-target" {
  bucket = aws_s3_bucket.salesforce-target.id
  policy = <<EOF
    {
    "Statement": [
        {
            "Effect": "Allow",
            "Sid": "AllowAppFlowDestinationActions",
            "Principal": {
                "Service": "appflow.amazonaws.com"
            },
            "Action": [
                "s3:PutObject",
                "s3:AbortMultipartUpload",
                "s3:ListMultipartUploadParts",
                "s3:ListBucketMultipartUploads",
                "s3:GetBucketAcl",
                "s3:PutObjectAcl"
            ],
            "Resource": [
                "arn:aws:s3:::salesforce-target",
                "arn:aws:s3:::salesforce-target/*"
            ]
        }
    ],
    "Version": "2012-10-17"
}
  EOF
}

//  connector profile for salesforce
resource "aws_appflow_connector_profile" "salesforce-profile" {
  name = "salesforce-profile"
  connector_type = "Salesforce"
  connection_mode = "Public"

  connector_profile_config {
    connector_profile_credentials {
      salesforce {
            access_token = "access_token"
            oauth_request {
              auth_code = "test_code"
              redirect_uri = "https://auth0.com"
            }
            refresh_token = "access_token"
          }
    }

    connector_profile_properties {
      salesforce {
        instance_url = "https://salesforce-example.com"
      }
    }
  }
}

resource "aws_appflow_flow" "salesforce-replicator" {
  name = "salesforce-replicator"

  source_flow_config {
    connector_type = "Salesforce"
    connector_profile_name = aws_appflow_connector_profile.salesforce-profile.name

    source_connector_properties {
      salesforce {
        object   = "Account"
      }
    }
  }

  destination_flow_config {
    connector_type = "S3"
    destination_connector_properties {
      s3 {
        bucket_name = aws_s3_bucket_policy.salesforce-target.bucket

        s3_output_format_config {
          prefix_config {
            prefix_type = "PATH"
          }
        }
      }
    }
  }

  task {
    source_fields     = ["ID", "JOURNEY_ID", "TRIGGERED_SEND_ID", "KEY", "NAME", "TYPE"]
    task_type         = "Map"

    connector_operator {
      s3 = "NO_OP"
    }
  }

  trigger_config {
    trigger_type = "OnDemand"
  }
}
