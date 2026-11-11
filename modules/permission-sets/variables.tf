variable "permission_sets" {
  description = <<-EOT
    Map of permission sets keyed by name (max 32 chars). Each entry carries its
    policies AND who gets it where (groups x accounts). Example:
      "DevOps-ReadOnly" = {
        managed_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
        groups              = ["aws-devops"]
        accounts            = ["111111111111"]
      }
  EOT
  type = map(object({
    description         = optional(string, "Managed by Terraform")
    session_duration    = optional(string, "PT1H") # ISO 8601, PT1H .. PT12H
    relay_state         = optional(string)         # console URL to land on after login
    managed_policy_arns = optional(list(string), [])
    customer_managed_policies = optional(list(object({
      name = string
      path = optional(string, "/")
    })), [])
    inline_policy = optional(string) # JSON string, max one per permission set
    permissions_boundary = optional(object({
      name = string
      path = optional(string, "/")
    }))
    groups   = optional(list(string), []) # Identity Center group DisplayNames (synced from IdP)
    accounts = optional(list(string), []) # 12-digit account IDs, as strings
  }))
}

variable "tags" {
  description = "Tags applied to every permission set"
  type        = map(string)
  default     = {}
}
