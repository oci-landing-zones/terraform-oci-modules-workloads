# Copyright (c) 2023 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

variable "tenancy_ocid" {}
variable "region" { description = "Your tenancy region" }
variable "user_ocid" { default = "" }
variable "fingerprint" { default = "" }
variable "private_key_path" { default = "" }
variable "private_key_password" { default = "" }
variable "clusters_configuration" {
  type = any
}
variable "workers_configuration" {
  type = any
}
variable "instances_configuration" {
  type = any
}
variable "bastions_configuration" {
  type = any
}
variable "sessions_configuration" {
  type = any
}
variable "ssh_private_key" {
  type = string
  default = "~/.ssh/id_rsa"
}