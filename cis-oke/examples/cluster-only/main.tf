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

module "oke" {
  source    = "../.."
  providers = { oci = oci }
  cluster_configuration = {
    name               = "cluster-only"
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
}
output "cluster" { value = module.oke.cluster }
