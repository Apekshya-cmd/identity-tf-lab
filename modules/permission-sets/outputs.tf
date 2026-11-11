output "instance_arn" {
  value = local.instance_arn
}

output "permission_set_arns" {
  description = "Permission set name => ARN"
  value       = { for k, v in aws_ssoadmin_permission_set.this : k => v.arn }
}

output "assignments" {
  description = "Every 'permission-set|group|account' combination this module manages"
  value       = keys(aws_ssoadmin_account_assignment.this)
}
