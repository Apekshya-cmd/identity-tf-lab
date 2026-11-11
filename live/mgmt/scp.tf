###############################################################################
# Guardrail: region-deny SCP, rolled out safely.
# Attached to an EMPTY test OU first. Move an account in only when testing.
###############################################################################

data "aws_organizations_organization" "this" {}

resource "aws_organizations_organizational_unit" "scp_test" {
  name      = "SCP-Test"
  parent_id = data.aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_policy" "region_deny" {
  name        = "deny-unapproved-regions"
  description = "Deny API calls outside approved regions, except global services and governance roles"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DenyOutsideApprovedRegions"
      Effect = "Deny"
      # Global services are served from us-east-1; never deny them.
      NotAction = [
        "iam:*", "organizations:*", "sts:*", "route53:*", "route53domains:*",
        "cloudfront:*", "support:*", "budgets:*", "health:*", "waf:*",
        "sso:*", "account:*", "ce:*", "trustedadvisor:*"
      ]
      Resource = "*"
      Condition = {
        StringNotEquals = { "aws:RequestedRegion" = var.allowed_regions }
        # Governance and emergency paths must keep working.
        ArnNotLike = {
          "aws:PrincipalARN" = [
            "arn:aws:iam::*:role/AWSControlTowerExecution",
            "arn:aws:iam::*:role/breakglass-*"
          ]
        }
      }
    }]
  })
}

resource "aws_organizations_policy_attachment" "region_deny_test" {
  policy_id = aws_organizations_policy.region_deny.id
  target_id = aws_organizations_organizational_unit.scp_test.id
}
