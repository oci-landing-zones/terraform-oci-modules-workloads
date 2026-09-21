module "configuration" {
  source                  = "./modules/configuration"
  cluster_configuration   = var.cluster_configuration
  workers_configuration   = var.workers_configuration
  compartments_dependency = var.compartments_dependency
  network_dependency      = var.network_dependency
  kms_dependency          = var.kms_dependency
  enable_output           = var.enable_output
  module_name             = var.module_name
}

locals {
  cluster_key              = "cluster"
  clusters                 = var.cluster_configuration == null ? {} : { "cluster" = module.configuration.contract.cluster_configuration }
  pools                    = module.configuration.normalized_worker_pools
  compartment_dependencies = var.compartments_dependency == null ? {} : var.compartments_dependency
  kms_dependencies         = var.kms_dependency == null ? {} : var.kms_dependency
  vcn_dependencies         = try(var.network_dependency.vcns, null) == null ? {} : var.network_dependency.vcns
  subnet_dependencies      = try(var.network_dependency.subnets, null) == null ? {} : var.network_dependency.subnets
  nsg_dependencies         = try(var.network_dependency.network_security_groups, null) == null ? {} : var.network_dependency.network_security_groups

  cluster_refs = { for k, c in local.clusters : k => {
    compartment  = c.compartment_id
    kms          = try(c.encryption.kube_secret_kms_key_id, null)
    signing_keys = module.configuration.cluster_collections[k].lists["image_signing.kms_key_ids"]
  } }
  compartment_refs = toset(compact(concat(
    [for c in values(local.cluster_refs) : c.compartment]
  )))
  subnet_refs = toset(compact(concat(
    [for c in values(local.clusters) : c.networking.api_endpoint_subnet_id],
    flatten([for c in values(local.clusters) : coalesce(c.networking.service_lb_subnet_ids, [])]),
    [for p in values(local.pools) : p.subnet_id], [for p in values(local.pools) : p.pod_subnet_id],
    flatten([for p in values(local.pools) : [for v in values(p.gva_secondary_vnics) : v.subnet_id]])
  )))
  nsg_refs = toset(compact(concat(
    flatten([for c in values(module.configuration.cluster_collections) : c.lists["networking.api_endpoint_nsg_ids"]]),
    flatten([for p in values(local.pools) : concat(coalesce(p.nsg_ids, []), coalesce(p.pod_nsg_ids, []), flatten([for v in values(p.gva_secondary_vnics) : v.nsg_ids]))])
  )))
  kms_refs = toset(compact(concat(
    [for c in values(local.cluster_refs) : c.kms], flatten([for c in values(local.cluster_refs) : c.signing_keys]),
    [for p in values(local.pools) : p.volume_kms_key_id]
  )))
  compartments = { for ref in local.compartment_refs : ref => startswith(ref, "ocid1.") ? ref : try(local.compartment_dependencies[ref].id, null) }
  subnets      = { for ref in local.subnet_refs : ref => startswith(ref, "ocid1.") ? ref : try(local.subnet_dependencies[ref].id, null) }
  nsgs         = { for ref in local.nsg_refs : ref => startswith(ref, "ocid1.") ? ref : try(local.nsg_dependencies[ref].id, null) }
  keys         = { for ref in local.kms_refs : ref => startswith(ref, "ocid1.") ? ref : try(local.kms_dependencies[ref].id, null) }
  vcns         = { for ref in toset([for c in values(local.clusters) : c.networking.vcn_id]) : ref => startswith(ref, "ocid1.") ? ref : try(local.vcn_dependencies[ref].id, null) }
  unresolved = concat(
    [for k, v in local.compartments : "compartments.${k}" if v == null],
    [for k, v in local.subnets : "subnets.${k}" if v == null],
    [for k, v in local.nsgs : "network_security_groups.${k}" if v == null],
    [for k, v in local.keys : "kms.${k}" if v == null],
    [for k, v in local.vcns : "vcns.${k}" if v == null]
  )
}

resource "terraform_data" "dependencies" {
  lifecycle {
    precondition {
      condition     = length(local.unresolved) == 0
      error_message = "Unresolved Landing Zone dependency references: ${join(", ", local.unresolved)}."
    }
  }
}
