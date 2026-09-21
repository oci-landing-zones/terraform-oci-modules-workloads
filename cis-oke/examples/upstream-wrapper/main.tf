terraform {
  required_version = ">= 1.4.0"
  required_providers {
    oci = { source = "oracle/oci", version = ">= 8.19.0, < 9.0.0" }
  }
}
variable "region" { type = string }
variable "compartment_id" { type = string }
variable "vcn_id" { type = string }
variable "api_subnet_id" { type = string }
variable "lb_subnet_id" { type = string }
variable "worker_subnet_id" { type = string }
variable "pod_subnet_id" { type = string }
variable "kubernetes_version" { type = string }

provider "oci" { region = var.region }

module "oke" {
  providers = { oci = oci }
  source    = "../.."
  clusters_configuration = {
    default_compartment_id = var.compartment_id
    clusters = {
      primary = {
        name               = "landing-zone-oke"
        cluster_type       = "enhanced"
        cni_type           = "native"
        kubernetes_version = var.kubernetes_version
        networking = {
          vcn_id                 = var.vcn_id
          api_endpoint_subnet_id = var.api_subnet_id
          service_lb_subnet_ids  = [var.lb_subnet_id]
        }
      }
    }
  }
  workers_configuration = {
    cluster_ref           = { key = "primary" }
    default_node_labels   = { team = "platform" }
    default_shape         = "VM.Standard.E4.Flex"
    default_size          = 3
    default_ocpus         = 2
    default_memory        = 32
    default_subnet_id     = var.worker_subnet_id
    default_pod_subnet_id = var.pod_subnet_id
    worker_pools = {
      general = {}
      batch = {
        size              = 2
        ocpus             = 4
        node_labels       = { team = "batch" }
        override_defaults = ["node_labels"]
      }
    }
  }
}
output "clusters" { value = module.oke.clusters }
output "node_pools" { value = module.oke.node_pools }
