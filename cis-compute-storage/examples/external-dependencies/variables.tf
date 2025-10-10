# Copyright (c) 2023 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

variable "tenancy_ocid" {}
variable "region" { description = "Your tenancy region" }
variable "user_ocid" { default = "" }
variable "fingerprint" { default = "" }
variable "private_key_path" { default = "" }
variable "private_key_password" { default = "" }

variable "block_volumes_replication_region" {
  description = "The replication region for block volumes. Leave unset if replication occurs to an availability domain within the block volume region."
  default     = null
}

variable "instances_configuration" {
  description = "Compute instances configuration attributes."
  type        = any
  default     = null
}

variable "storage_configuration" {
  description = "Storage configuration attributes."
  type        = any
  default     = null
}

variable "oci_compartments_dependency" {
  type = object({
    bucket = string
    object = string
  })
  default = null
}

variable "oci_network_dependency" {
  type = object({
    bucket = string
    object = string
  })
  default = null
}

variable "oci_kms_dependency" {
  type = object({
    bucket = string
    object = string
  })
  default = null
}

variable "oci_compute_dependency" {
  type = object({
    bucket = string
    object = string
  })
  default = null
}