locals {
  cluster_settings = { for k, c in local.clusters : k => {
    compartment_id   = try(local.compartments[local.cluster_refs[k].compartment], null)
    vcn_id           = local.vcns[c.networking.vcn_id]
    subnet_id        = local.subnets[c.networking.api_endpoint_subnet_id]
    kms_key_id       = local.cluster_refs[k].kms == null ? null : local.keys[local.cluster_refs[k].kms]
    pods_cidr        = try(c.options.kubernetes_network_config.pods_cidr, null)
    services_cidr    = try(c.options.kubernetes_network_config.services_cidr, null)
    cis_level        = coalesce(c.cis_level, var.clusters_configuration.default_cis_level, "1")
    lb_subnets       = [for ref in coalesce(c.networking.service_lb_subnet_ids, []) : local.subnets[ref]]
    defined_tags     = module.configuration.cluster_collections[k].maps["defined_tags"]
    freeform_tags    = merge({ state_id = k, role = "cluster" }, local.cislz_module_tag, module.configuration.cluster_collections[k].maps["freeform_tags"])
    pv_defined_tags  = module.configuration.cluster_collections[k].maps["options.persistent_volume_config.defined_tags"]
    pv_freeform_tags = merge(local.cislz_module_tag, module.configuration.cluster_collections[k].maps["options.persistent_volume_config.freeform_tags"])
    lb_defined_tags  = module.configuration.cluster_collections[k].maps["options.service_lb_config.defined_tags"]
    lb_freeform_tags = merge(local.cislz_module_tag, module.configuration.cluster_collections[k].maps["options.service_lb_config.freeform_tags"])
  } }
}

data "oci_containerengine_cluster_option" "cluster_options" {
  for_each          = local.clusters
  cluster_option_id = "all"
  compartment_id    = local.cluster_settings[each.key].compartment_id
}

resource "terraform_data" "cluster_validation" {
  for_each = local.clusters
  input    = merge(local.cluster_settings[each.key], { resource_address = "module.cluster[${jsonencode(each.key)}].module.cluster[0].oci_containerengine_cluster.k8s_cluster" })
  lifecycle {
    precondition {
      condition     = length(distinct([for k in local.cluster_managed_pool_keys[each.key] : local.pool_settings[k].ssh_public_key])) <= 1 && length(distinct([for k in local.cluster_managed_pool_keys[each.key] : coalesce(local.pools[k].pv_transit_encryption, false)])) <= 1
      error_message = "Cluster ${each.key}: official upstream root requires the same SSH key and transit-encryption setting for all pools. Differing values are blocked."
    }
    precondition {
      condition     = length(distinct([for k in local.cluster_pool_keys[each.key] : coalesce(local.pools[k].name, k)])) == length(local.cluster_pool_keys[each.key])
      error_message = "Cluster ${each.key}: pool names must be unique within the upstream root module."
    }
    precondition {
      condition     = length(local.cluster_pool_keys[each.key]) == 0 ? true : sum([for k in local.cluster_pool_keys[each.key] : coalesce(local.pools[k].size, 0)]) > 0
      error_message = "Cluster ${each.key}: upstream hides pool outputs when total pool size is zero; this configuration is blocked pending upstream support."
    }
    precondition {
      condition     = local.cluster_settings[each.key].compartment_id != null
      error_message = "Cluster ${each.key}: specify a resolvable compartment_id or default_compartment_id."
    }
    precondition {
      condition     = local.cluster_settings[each.key].cis_level != "2" || local.cluster_settings[each.key].kms_key_id != null
      error_message = "Cluster ${each.key}: CIS level 2 requires a customer-managed secret-encryption key."
    }
    precondition {
      condition     = each.value.kubernetes_version == null ? true : contains(data.oci_containerengine_cluster_option.cluster_options[each.key].kubernetes_versions, each.value.kubernetes_version)
      error_message = "Cluster ${each.key}: kubernetes_version is not supported by OCI."
    }
    precondition {
      condition     = length([for k, c in local.cluster_settings : k if c.vcn_id == local.cluster_settings[each.key].vcn_id]) == 1
      error_message = "Cluster ${each.key}: only one configured cluster per resolved VCN is allowed."
    }
    precondition {
      condition     = contains(["native", "flannel"], lower(each.value.cni_type))
      error_message = "Cluster ${each.key}: cni_type must be native or flannel."
    }
    precondition {
      condition     = length(local.cluster_settings[each.key].lb_subnets) == 1
      error_message = "Cluster ${each.key}: official upstream v5.5.1 requires exactly one service_lb_subnet_ids entry. Omitted/multiple LB subnets are blocked pending upstream support."
    }
    precondition {
      condition     = !try(coalesce(each.value.image_signing.image_policy_enabled, false), false) || length(local.cluster_refs[each.key].signing_keys) > 0
      error_message = "Cluster ${each.key}: enabled image signing requires at least one KMS key."
    }
  }
  depends_on = [terraform_data.dependencies]
}

locals {
  cluster_managed_pool_keys = { for c in keys(local.clusters) : c => [for k, p in local.pools : k if p.cluster_ref.key == c && p.mode == "node-pool"] }
  cluster_pool_keys         = { for c in keys(local.clusters) : c => [for k, p in local.pools : k if p.cluster_ref.key == c] }
}

# Keep discovery inputs independent of validation-resource creation. A module-wide
# depends_on defers upstream AD discovery and makes fault-domain for_each keys unknown.
# Validation resources retain blocking preconditions in ordinary plan/apply runs.
module "cluster" {
  providers                    = { oci = oci, oci.home = oci }
  create_cluster               = true
  create_vcn                   = false
  create_drg                   = false
  create_bastion               = false
  cluster_addons               = {}
  cluster_addons_to_remove     = {}
  create_operator              = false
  create_iam_resources         = false
  create_iam_tag_namespace     = false
  create_iam_defined_tags      = false
  create_iam_worker_policy     = "never"
  create_iam_autoscaler_policy = "never"
  create_iam_operator_policy   = "never"
  create_iam_kms_policy        = "never"
  create_iam_karpenter_policy  = "never"
  vcn_create_internet_gateway  = "never"
  vcn_create_nat_gateway       = "never"
  vcn_create_service_gateway   = "never"
  # Only affects upstream-created networking/standalone compute, neither managed nor virtual pools.
  assign_dns              = false
  output_detail           = true
  load_balancers          = "internal"
  preferred_load_balancer = "internal"
  subnets = {
    for role in ["bastion", "operator", "cp", "int_lb", "pub_lb", "workers", "pods"] : role => {
      create = "never"
      id     = role == "cp" ? local.cluster_settings[each.key].subnet_id : (role == "int_lb" ? try(local.cluster_settings[each.key].lb_subnets[0], null) : null)
    }
  }
  nsgs                              = { for role in ["bastion", "operator", "cp", "int_lb", "pub_lb", "workers", "pods"] : role => { create = "never" } }
  worker_pools                      = { for k, p in local.pools : coalesce(p.name, k) => local.upstream_pools[k] if p.cluster_ref.key == each.key }
  ssh_public_key                    = try(local.pool_settings[local.cluster_managed_pool_keys[each.key][0]].ssh_public_key, null)
  worker_pv_transit_encryption      = try(coalesce(local.pools[local.cluster_managed_pool_keys[each.key][0]].pv_transit_encryption, false), false)
  worker_disable_default_cloud_init = try(var.workers_configuration.default_disable_default_cloud_init, false)
  # Effective custom parts are selected per pool by configuration (local replaces global).
  worker_cloud_init                 = []
  worker_is_public                  = false
  for_each                          = local.clusters
  source                            = "git::https://github.com/oracle-terraform-modules/terraform-oci-oke.git?ref=v5.5.1"
  compartment_id                    = local.cluster_settings[each.key].compartment_id
  state_id                          = each.key
  cluster_name                      = each.value.name
  cluster_type                      = "enhanced"
  kubernetes_version                = each.value.kubernetes_version != null ? each.value.kubernetes_version : reverse(data.oci_containerengine_cluster_option.cluster_options[each.key].kubernetes_versions)[0]
  cni_type                          = lower(each.value.cni_type) == "native" ? "npn" : "flannel"
  vcn_id                            = local.cluster_settings[each.key].vcn_id
  control_plane_is_public           = false
  assign_public_ip_to_control_plane = false
  control_plane_nsg_ids             = distinct([for ref in module.configuration.cluster_collections[each.key].lists["networking.api_endpoint_nsg_ids"] : local.nsgs[ref]])
  cluster_kms_key_id                = local.cluster_settings[each.key].kms_key_id
  pods_cidr                         = try(each.value.options.kubernetes_network_config.pods_cidr, null)
  services_cidr                     = try(each.value.options.kubernetes_network_config.services_cidr, null)
  oke_ip_families                   = ["IPv4"]
  backend_nsg_ids                   = []
  use_signed_images                 = try(coalesce(each.value.image_signing.image_policy_enabled, false), false)
  image_signing_keys                = distinct([for ref in local.cluster_refs[each.key].signing_keys : local.keys[ref]])
  use_defined_tags                  = false
  tag_namespace                     = "oke"
  cluster_defined_tags              = local.cluster_settings[each.key].defined_tags
  cluster_freeform_tags             = local.cluster_settings[each.key].freeform_tags
  persistent_volume_defined_tags    = local.cluster_settings[each.key].pv_defined_tags
  persistent_volume_freeform_tags   = local.cluster_settings[each.key].pv_freeform_tags
  service_lb_defined_tags           = local.cluster_settings[each.key].lb_defined_tags
  service_lb_freeform_tags          = local.cluster_settings[each.key].lb_freeform_tags
  oidc_discovery_enabled            = lower(each.value.cni_type) == "native" && try(each.value.options.openid_connect.enable_discovery, false)
  oidc_token_auth_enabled           = try(each.value.options.openid_connect.enable_authentication, false)
  oidc_token_authentication_config = merge(try(each.value.options.openid_connect, null), {
    required_claims = [for k, v in coalesce(try(each.value.options.openid_connect.required_claims, null), {}) : { key = k, value = v }]
  })
}

# Upstream exports cluster identity/endpoints, not the resource object. Read back
# OCI attributes to retain the existing keyed cluster output for LZ consumers.
data "oci_containerengine_cluster" "managed" {
  for_each   = local.clusters
  cluster_id = module.cluster[each.key].cluster_id
}
