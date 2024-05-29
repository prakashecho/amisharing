provider "aws" {
  region = "us-east-1"
}

resource "aws_ami_copy" "encrypted_ami" {
  name              = "encrypted-ami"
  source_ami_id     = "ami-04b70fa74e45c3917"
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
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Id": "key-policy-example",
  "Statement": [
    {
      "Sid": "Allow use of the key",
      "Effect": "Allow
