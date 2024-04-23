# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

variable "tenancy_ocid" {}

variable "user_ocid" {
  default = ""
}
variable "fingerprint" {
  default = ""
}
variable "private_key_path" {
  default = ""
}
variable "private_key_password" {
  default = ""
}

variable "region" {
    type = string
}

variable "cluster_compartment_id" {
    type = string
}

variable "cluster_ad" {
    type = string
    default = "1"
}

variable "cluster_type" {
    type = string
    default = "cluster_network"
}

variable "cluster_name" {
    type = string
}

variable "cluster_network_pool_name" {
    type = string
    default = "cluster-network-pool"
}

variable "cluster_network_pool_size" {
    type = number
    default = 1
}

variable "cluster_network_vcn_compartment_id" {
    type = string
    default = null
}

variable "cluster_network_vcn_id" {
    type = string
    default = null
}

variable "cluster_network_subnet_id" {
    type = string
    default = null
}

variable "cluster_network_ipv6_cidrs_enable" {
    type = bool
    default = false
}

variable "cluster_network_ipv6_cidrs" {
    type = list(string)
    default = []
}

variable "cluster_network_secondary_vnic_enable" {
    type = bool
    default = false
}

variable "cluster_network_secondary_vnic_name" {
    type = string
    default = null
}

variable "cluster_network_secondary_vnic_vcn_compartment_id" {
    type = string
    default = null
}

variable "cluster_network_secondary_vnic_vcn_id" {
    type = string
    default = null
}

variable "cluster_network_secondary_vnic_subnet_id" {
    type = string
    default = null
}

variable "cluster_network_secondary_vnic_ipv6_cidrs_enable" {
    type = bool
    default = false
}

variable "cluster_network_secondary_vnic_ipv6_cidrs" {
    type = list(string)
    default = []
}

variable "cluster_network_source" {
    type = string
    default = "image"
}

variable "cluster_network_source_image_compartment_id" {
    type = string
    default = null
}

variable "cluster_network_source_image_id" {
    type = string
    default = null
}

variable "cluster_network_source_image_shape" {
    type = string
    default = "BM.Optimized3.36"
}

variable "cluster_network_source_instance_compartment_id" {
    type = string
    default = null
}

variable "cluster_network_source_instance_id" {
    type = string
    default = null
}

variable "compute_cluster_size" {
    type = number
    default = 1
}

variable "compute_cluster_source_image_compartment_id" {
    type = string
    default = null
}

variable "compute_cluster_source_image_id" {
    type = string
    default = null
}

variable "compute_cluster_source_image_shape" {
    type = string
    default = null
}

variable "compute_cluster_vcn_compartment_id" {
    type = string
    default = null
}

variable "compute_cluster_vcn_id" {
    type = string
    default = null
}

variable "compute_cluster_subnet_id" {
    type = string
    default = null
}

variable "compute_cluster_nsg_id" {
    type = string
    default = null
}


