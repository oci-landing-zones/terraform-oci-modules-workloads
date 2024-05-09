variable "tenancy_ocid" {}
variable "home_region" { description = "Your tenancy home region" }
variable "user_ocid" { default = "" }
variable "fingerprint" { default = "" }
variable "private_key_path" { default = "" }
variable "private_key_password" { default = "" }

variable "dynamic_groups_configuration" {
  type = any
}
variable "policies_configuration" {
  type = any
}