output "permission_set_arns" {
  value = module.permission_sets.permission_set_arns
}

output "assignments" {
  description = "permission-set|group|account combinations managed here"
  value       = module.permission_sets.assignments
}

output "nonprod_accounts" {
  value = local.nonprod_accounts
}

output "prod_accounts" {
  value = local.prod_accounts
}

output "scp_test_ou_id" {
  value = aws_organizations_organizational_unit.scp_test.id
}
