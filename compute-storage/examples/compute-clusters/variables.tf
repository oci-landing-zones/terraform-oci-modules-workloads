# Copyright (c) 2023 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

variable "tenancy_ocid" {}
variable "region" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "private_key_password" {}

variable "clusters_configuration" {
  description = "RDMA clusters configuration attributes."
  type = any
  default = null
}

variable "cluster_instances_configuration" {
  description = "RDMA cluster instances configuration attributes"
  type = any
  default = null
}

variable "instances_configuration" {
  description = "Compute instances configuration attributes."
  type = any
  default = null
}