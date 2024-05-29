provider "aws" {
  region = "us-east-1"
}

resource "aws_ami_copy" "encrypted_ami" {
  name              = "encrypted-ami"
  source_ami_id     = "ami-0ec45b580774622a1"
  source_ami_region = "us-east-1"
  encrypted         = true
  kms_key_id        = "arn:aws:kms:us-east-1:874599947932:key/22ad3ccd-28a1-4d05-ad73-5f284cea93b3"
}

output "new_ami_id" {
  value = aws_ami_copy.encrypted_ami.id
}

data "aws_ami" "encrypted_ami" {
  most_recent = true
  filter {
    name   = "image-id"
    values = [aws_ami_copy.encrypted_ami.id]
  }
}

data "aws_ebs_snapshot" "snapshot" {
  most_recent = true
  filter {
    name   = "description"
    values = ["*${aws_ami_copy.encrypted_ami.id}*"]
  }
}

resource "null_resource" "share_ami" {
  provisioner "local-exec" {
    command = "aws ec2 modify-image-attribute --image-id ${aws_ami_copy.encrypted_ami.id} --launch-permission \"Add=[{UserId=280435798514}]\""
  }
}

resource "null_resource" "share_snapshot" {
  provisioner "local-exec" {
    command = "aws ec2 modify-snapshot-attribute --snapshot-id ${data.aws_ebs_snapshot.snapshot.id} --attribute createVolumePermission --operation-type add --user-ids 280435798514"
  }
}

resource "aws_kms_key_policy" "key_policy" {
  key_id = "arn:aws:kms:us-east-1:874599947932:key/22ad3ccd-28a1-4d05-ad73-5f284cea93b3"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Id" : "key-default-1",
    "Statement" : [
      {
        "Sid" : "Enable IAM User Permissions",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "*"
        },
        "Action" : "kms:*",
        "Resource" : "*"
      },
      {
        "Sid" : "Allow access for Key Administrators",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::874599947932:role/KMSAdminRole"
        },
        "Action" : "kms:*",
        "Resource" : "*"
      },
      {
        "Sid" : "Allow usage for encrypted resources",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "*"
        },
        "Action" : [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "Allow attachment of persistent resources",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "*"
        },
        "Action" : [
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ],
        "Resource" : "*",
        "Condition" : {
          "Bool" : {
            "kms:GrantIsForAWSResource" : "true"
          }
        }
      }
    ]
  })
}

}
EOF
}
