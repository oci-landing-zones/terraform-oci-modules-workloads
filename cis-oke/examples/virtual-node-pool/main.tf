terraform {
  required_version = ">= 1.4.0"
  required_providers {
    oci = { source = "oracle/oci", version = ">= 8.19.0, < 9.0.0" }
  }
}
provider "oci" { region = var.region }

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
variable "pod_nsg_id" { type = string }

module "oke" {
  source    = "../.."
  providers = { oci = oci }
  cluster_configuration = {
    name               = "virtual-node-pool"
    compartment_id     = var.compartment_id
    kubernetes_version = var.kubernetes_version
    cluster_type       = "enhanced"
    cni_type           = "native"

    networking = {
      vcn_id                 = var.vcn_id
      api_endpoint_subnet_id = var.api_subnet_id
      api_endpoint_nsg_ids   = [var.api_nsg_id]
      service_lb_subnet_ids  = [var.lb_subnet_id]
    }
  }
  workers_configuration = {
    worker_pools = {
      virtual = {
        mode          = "virtual-node-pool"
        shape         = "Pod.Standard.E4.Flex"
        size          = 3
        subnet_id     = var.worker_subnet_id
        nsg_ids       = [var.worker_nsg_id]
        pod_subnet_id = var.pod_subnet_id
        pod_nsg_ids   = [var.pod_nsg_id]
        taints        = [{ key = "workload", value = "virtual", effect = "NoSchedule" }]
      }
    }
  }
}
output "cluster" { value = module.oke.cluster }
output "virtual_node_pools" { value = module.oke.virtual_node_pools }
