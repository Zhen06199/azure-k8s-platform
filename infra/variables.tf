variable "subscription_id" {
  type = string
}

variable "location" {
  type    = string
  default = "germanywestcentral"
}

variable "ci_principal_id" {
  type        = string
  description = "Object ID of the GitHub Actions service principal (bootstrap output ci_principal_id)"
}
