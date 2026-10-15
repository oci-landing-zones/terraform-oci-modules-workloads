terraform {
  required_version = ">= 1.4.0"
  required_providers {
    oci = { source = "oracle/oci", version = ">= 8.19.0, < 9.0.0" }
  }
}
variable "region" { type = string }
# Each entry is validated by CIS OKE's concrete cluster and worker input types.
# Any permits different optional pool settings in different cluster configurations.
variable "deployments" {
  type    = any
  default = {}
}
provider "oci" { region = var.region }
module "oke" {
  for_each                = var.deployments
  source                  = "../.."
  providers               = { oci = oci }
  cluster_configuration   = each.value.cluster_configuration
  workers_configuration   = try(each.value.workers_configuration, null)
  compartments_dependency = try(each.value.compartments_dependency, null)
  network_dependency      = try(each.value.network_dependency, null)
  kms_dependency          = try(each.value.kms_dependency, null)
}
output "deployments" {
  value = { for key, deployment in module.oke : key => {
    cluster            = deployment.cluster
    node_pools         = deployment.node_pools
    virtual_node_pools = deployment.virtual_node_pools
    nodes              = deployment.nodes
  } }
}
