data "aws_caller_identity" "current" {}

locals {
  toy_instance_arn = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/*"
}

# Trust anchor: AWS trusts certs signed by your private CA
resource "aws_rolesanywhere_trust_anchor" "instance_starter" {
  name    = "instance-starter-ca"
  enabled = true

  source {
    source_type = "CERTIFICATE_BUNDLE"
    source_data {
      x509_certificate_data = file("${path.module}/pki/ca.crt")
    }
  }
}

# Trust policy: only Roles Anywhere, only this trust anchor, only CN=instance-starter
data "aws_iam_policy_document" "instance_starter_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession", "sts:SetSourceIdentity"]

    principals {
      type        = "Service"
      identifiers = ["rolesanywhere.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalTag/x509Subject/CN"
      values   = ["instance-starter"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_rolesanywhere_trust_anchor.instance_starter.arn]
    }
  }
}

# Permissions: exactly the four calls the app makes, scoped to the toy instances
data "aws_iam_policy_document" "instance_starter_app" {
  statement {
    sid       = "Describe"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"] # Describe can't be resource-scoped
  }

  statement {
    sid       = "StartStopToyInstances"
    actions   = ["ec2:StartInstances", "ec2:StopInstances"]
    resources = [local.toy_instance_arn]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Role"
      values   = ["instance-starter-toy"]
    }
  }

  statement {
    sid       = "TagExpirationOnly"
    actions   = ["ec2:CreateTags"]
    resources = [local.toy_instance_arn]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Role"
      values   = ["instance-starter-toy"]
    }

    # Can't retag Role 
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "aws:TagKeys"
      values   = ["ExpirationTime"]
    }
  }
}

resource "aws_iam_role" "instance_starter_app" {
  name                 = "instance-starter-app"
  assume_role_policy   = data.aws_iam_policy_document.instance_starter_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "instance_starter_app" {
  name   = "instance-starter-app"
  role   = aws_iam_role.instance_starter_app.id
  policy = data.aws_iam_policy_document.instance_starter_app.json
}

# Profile: which role(s) a cert can get, and for how long
resource "aws_rolesanywhere_profile" "instance_starter" {
  name             = "instance-starter-app"
  enabled          = true
  role_arns        = [aws_iam_role.instance_starter_app.arn]
  duration_seconds = 3600
}

output "rolesanywhere_trust_anchor_arn" { value = aws_rolesanywhere_trust_anchor.instance_starter.arn }
output "rolesanywhere_profile_arn" { value = aws_rolesanywhere_profile.instance_starter.arn }
output "rolesanywhere_role_arn" { value = aws_iam_role.instance_starter_app.arn }