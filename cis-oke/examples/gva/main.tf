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
variable "gva_subnet_id" { type = string }
variable "gva_nsg_id" { type = string }

module "oke" {
  source    = "../.."
  providers = { oci = oci }
  cluster_configuration = {
    name               = "gva"
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
    default_shape     = "VM.Standard.E4.Flex"
    default_size      = 3
    default_ocpus     = 2
    default_memory    = 32
    default_subnet_id = var.worker_subnet_id
    default_nsg_ids   = [var.worker_nsg_id]
    default_cloud_init = [{
      content_type = "text/cloud-config"
      content      = "#cloud-config\nwrite_files:\n  - path: /etc/oke-example\n    content: gva-example\n"
    }]
    worker_pools = {
      general = {
        gva_secondary_vnics = {
          data = {
            subnet_id             = var.gva_subnet_id
            nsg_ids               = [var.gva_nsg_id]
            application_resources = ["example.com/data"]
            ip_count              = 32
          }
        }
      }
    }
  }
}
output "cluster" { value = module.oke.cluster }
output "node_pools" { value = module.oke.node_pools }
