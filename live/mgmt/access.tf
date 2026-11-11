###############################################################################
# Access model: permission sets = job functions; assignments derived from OUs.
# A new account moved into the NonProd OU gets access on the next pipeline run,
# with no code change.
###############################################################################

data "aws_organizations_organizational_unit_descendant_accounts" "nonprod" {
  parent_id = var.nonprod_ou_id
}

data "aws_organizations_organizational_unit_descendant_accounts" "prod" {
  parent_id = var.prod_ou_id
}

locals {
  nonprod_accounts = [
    for a in data.aws_organizations_organizational_unit_descendant_accounts.nonprod.accounts :
    a.id if a.status == "ACTIVE"
  ]
  prod_accounts = [
    for a in data.aws_organizations_organizational_unit_descendant_accounts.prod.accounts :
    a.id if a.status == "ACTIVE"
  ]

  permission_sets = {

    # Standard access: read-only everywhere for the platform team.
    "TF-ReadOnly" = {
      description         = "Standard read-only access (job function)"
      session_duration    = "PT4H"
      managed_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
      groups              = ["aws-devops"]
      accounts            = concat(local.nonprod_accounts, local.prod_accounts)
    }

    # Standard access: developers write in non-prod only, fenced by a boundary.
    # lab-app-bucket-access and lab-dev-boundary exist in NonProd accounts via the
    # lab-baseline StackSet, so this can never be provisioned into Prod accounts.
    "TF-Developer" = {
      description               = "Developer write access in non-prod, with boundary"
      session_duration          = "PT8H"
      managed_policy_arns       = ["arn:aws:iam::aws:policy/PowerUserAccess"]
      customer_managed_policies = [{ name = "lab-app-bucket-access" }]
      permissions_boundary      = { name = "lab-dev-boundary" }
      inline_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid    = "DenyOutsideMumbai"
          Effect = "Deny"
          NotAction = [
            "iam:*", "sts:*", "support:*", "cloudfront:*", "route53:*",
            "health:*", "s3:ListAllMyBuckets", "s3:GetBucketLocation"
          ]
          Resource  = "*"
          Condition = { StringNotEquals = { "aws:RequestedRegion" = ["ap-south-1"] } }
        }]
      })
      groups   = ["aws-developers"]
      accounts = local.nonprod_accounts
    }

    # Developers are read-only in prod (reuses the job-function pattern).
    "TF-Developer-ProdRead" = {
      description         = "Developer read-only access in prod"
      session_duration    = "PT4H"
      managed_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
      groups              = ["aws-developers"]
      accounts            = local.prod_accounts
    }

    # Privileged access: exists, but NO standing assignment. Granted time-bound only.
    "TF-Admin-Elevated" = {
      description         = "Privileged access - time-bound assignment only"
      session_duration    = "PT1H"
      managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
      groups              = []
      accounts            = []
    }
  }
}

module "permission_sets" {
  source          = "../../modules/permission-sets"
  permission_sets = local.permission_sets
  tags = {
    Stack = "identity-access"
  }
}
