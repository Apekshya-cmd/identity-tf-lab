###############################################################################
# Identity Center permission sets + assignments, driven by one map.
# Must run with credentials for the management account (or the Identity Center
# delegated admin account, for permission sets not provisioned to management).
###############################################################################

data "aws_ssoadmin_instances" "this" {}

locals {
  instance_arn      = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]

  # Flatten "permission set -> list" into one map per resource type, so each
  # attachment/assignment gets a stable, readable key in state.
  managed_policy_attachments = {
    for item in flatten([
      for ps_name, ps in var.permission_sets : [
        for arn in ps.managed_policy_arns : { ps = ps_name, arn = arn }
      ]
    ]) : "${item.ps}|${item.arn}" => item
  }

  customer_policy_attachments = {
    for item in flatten([
      for ps_name, ps in var.permission_sets : [
        for p in ps.customer_managed_policies : { ps = ps_name, name = p.name, path = p.path }
      ]
    ]) : "${item.ps}|${item.path}${item.name}" => item
  }

  inline_policies = { for k, v in var.permission_sets : k => v if v.inline_policy != null }
  boundaries      = { for k, v in var.permission_sets : k => v if v.permissions_boundary != null }

  # Every group referenced anywhere, looked up once.
  all_groups = toset(flatten([for ps in var.permission_sets : ps.groups]))

  # permission set x group x account
  assignments = {
    for item in flatten([
      for ps_name, ps in var.permission_sets : [
        for g in ps.groups : [
          for acct in ps.accounts : { ps = ps_name, group = g, account = acct }
        ]
      ]
    ]) : "${item.ps}|${item.group}|${item.account}" => item
  }
}

# --- Permission sets ---------------------------------------------------------

resource "aws_ssoadmin_permission_set" "this" {
  for_each = var.permission_sets

  instance_arn     = local.instance_arn
  name             = each.key
  description      = each.value.description
  session_duration = each.value.session_duration
  relay_state      = each.value.relay_state
  tags             = var.tags
}

# --- Policies on the permission sets -----------------------------------------

resource "aws_ssoadmin_managed_policy_attachment" "this" {
  for_each = local.managed_policy_attachments

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.ps].arn
  managed_policy_arn = each.value.arn
}

# Only a REFERENCE (name + path). The policy itself must already exist in every
# account this permission set is assigned to, or provisioning to that account fails.
resource "aws_ssoadmin_customer_managed_policy_attachment" "this" {
  for_each = local.customer_policy_attachments

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.ps].arn

  customer_managed_policy_reference {
    name = each.value.name
    path = each.value.path
  }
}

resource "aws_ssoadmin_permission_set_inline_policy" "this" {
  for_each = local.inline_policies

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.key].arn
  inline_policy      = each.value.inline_policy
}

# Boundary is also a customer-managed policy reference -> must exist in target accounts.
resource "aws_ssoadmin_permissions_boundary_attachment" "this" {
  for_each = local.boundaries

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.key].arn

  permissions_boundary {
    customer_managed_policy_reference {
      name = each.value.permissions_boundary.name
      path = each.value.permissions_boundary.path
    }
  }
}

# --- Groups: LOOKED UP, not created (the IdP owns them via SCIM) --------------

data "aws_identitystore_group" "this" {
  for_each = local.all_groups

  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = each.value
    }
  }
}

# --- Assignments: group + permission set + account ---------------------------

resource "aws_ssoadmin_account_assignment" "this" {
  for_each = local.assignments

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.ps].arn

  principal_type = "GROUP"
  principal_id   = data.aws_identitystore_group.this[each.value.group].group_id

  target_type = "AWS_ACCOUNT"
  target_id   = each.value.account

  # Attach all policies BEFORE the first provisioning into an account,
  # so the role is never created half-configured.
  depends_on = [
    aws_ssoadmin_managed_policy_attachment.this,
    aws_ssoadmin_customer_managed_policy_attachment.this,
    aws_ssoadmin_permission_set_inline_policy.this,
    aws_ssoadmin_permissions_boundary_attachment.this,
  ]
}
