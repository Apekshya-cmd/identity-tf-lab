variable "region" {
  description = "Identity Center home region"
  type        = string
  default     = "ap-south-1"
}

variable "nonprod_ou_id" {
  description = "ID of the NonProd OU (lab-org stack output NonProdOUId)"
  type        = string
}

variable "prod_ou_id" {
  description = "ID of the Prod OU (lab-org stack output ProdOUId)"
  type        = string
}

variable "allowed_regions" {
  description = "Regions allowed by the SCP. Keep the Control Tower home region in this list."
  type        = list(string)
  default     = ["ap-south-1", "us-east-1"]
}
