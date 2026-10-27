terraform {
  required_version = ">= 1.4.0"
  required_providers {
    oci = { source = "oracle/oci", version = ">= 8.19.0, < 9.0.0" }
  }
}
provider "oci" { region = var.region }

variable "tenancy_id" { type = string }
variable "region" { type = string }
variable "compartment_id" { type = string }
variable "vcn_id" { type = string }
variable "api_subnet_id" { type = string }
variable "lb_subnet_id" { type = string }
variable "kubernetes_version" { type = string }
variable "api_nsg_id" { type = string }
variable "worker_subnet_id" { type = string }
variable "worker_nsg_id" { type = string }
variable "pod_subnet_id" { type = string }
variable "cluster_kms_key_id" { type = string }
variable "worker_kms_key_id" { type = string }

module "oke" {
  tenancy_id = var.tenancy_id
  source     = "../.."
  providers  = { oci = oci }
  cluster_configuration = {
    name               = "cis-level2"
    compartment_id     = var.compartment_id
    kubernetes_version = var.kubernetes_version
    cluster_type       = "enhanced"
    cni_type           = "native"
    cis_level          = "2"
    encryption         = { kube_secret_kms_key_id = var.cluster_kms_key_id }
    networking = {
      vcn_id                 = var.vcn_id
      api_endpoint_subnet_id = var.api_subnet_id
      api_endpoint_nsg_ids   = [var.api_nsg_id]
      service_lb_subnet_ids  = [var.lb_subnet_id]
    }
  }
  workers_configuration = {
    default_shape                 = "VM.Standard.E4.Flex"
    default_size                  = 3
    default_ocpus                 = 2
    default_memory                = 32
    default_subnet_id             = var.worker_subnet_id
    default_nsg_ids               = [var.worker_nsg_id]
    default_pod_subnet_id         = var.pod_subnet_id
    default_volume_kms_key_id     = var.worker_kms_key_id
    default_pv_transit_encryption = true
    worker_pools = {
      general = {}
    }
  }
}
output "cluster" { value = module.oke.cluster }
output "node_pools" { value = module.oke.node_pools }
