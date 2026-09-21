# Resolve inherited collections before dependency lookup and resource validation.
locals {
  configured_clusters = var.clusters_configuration == null ? {} : var.clusters_configuration.clusters
  cluster_map_defaults = {
    "defined_tags"                                   = try(var.clusters_configuration.default_cluster_defined_tags, null)
    "freeform_tags"                                  = try(var.clusters_configuration.default_cluster_freeform_tags, null)
    "options.persistent_volume_config.defined_tags"  = try(var.clusters_configuration.default_pv_defined_tags, null)
    "options.persistent_volume_config.freeform_tags" = try(var.clusters_configuration.default_pv_freeform_tags, null)
    "options.service_lb_config.defined_tags"         = try(var.clusters_configuration.default_service_lb_defined_tags, null)
    "options.service_lb_config.freeform_tags"        = try(var.clusters_configuration.default_service_lb_freeform_tags, null)
  }
  cluster_list_defaults = {
    "networking.api_endpoint_nsg_ids" = try(var.clusters_configuration.default_api_endpoint_nsg_ids, null)
    "image_signing.kms_key_ids"       = try(var.clusters_configuration.default_image_signing_key_ids, null)
  }
  cluster_map_values = { for k, c in local.configured_clusters : k => {
    "defined_tags"                                   = try(c.defined_tags, null)
    "freeform_tags"                                  = try(c.freeform_tags, null)
    "options.persistent_volume_config.defined_tags"  = try(c.options.persistent_volume_config.defined_tags, null)
    "options.persistent_volume_config.freeform_tags" = try(c.options.persistent_volume_config.freeform_tags, null)
    "options.service_lb_config.defined_tags"         = try(c.options.service_lb_config.defined_tags, null)
    "options.service_lb_config.freeform_tags"        = try(c.options.service_lb_config.freeform_tags, null)
  } }
  cluster_list_values = { for k, c in local.configured_clusters : k => {
    "networking.api_endpoint_nsg_ids" = try(c.networking.api_endpoint_nsg_ids, null)
    "image_signing.kms_key_ids"       = try(c.image_signing.kms_key_ids, null)
  } }
  cluster_collections = { for k, c in local.configured_clusters : k => {
    maps = { for field, value in local.cluster_map_values[k] : field => (
      contains(c.override_defaults, field) ? coalesce(value, {}) : merge(coalesce(local.cluster_map_defaults[field], {}), coalesce(value, {}))
    ) }
    lists = { for field, value in local.cluster_list_values[k] : field => distinct(
      contains(c.override_defaults, field) ? coalesce(value, []) : concat(coalesce(local.cluster_list_defaults[field], []), coalesce(value, []))
    ) }
  } }
}
output "cluster_collections" {
  value = local.cluster_collections
  precondition {
    condition = alltrue(flatten([for k, c in local.configured_clusters : [for field in c.override_defaults :
      try(local.cluster_map_values[k][field] != null, local.cluster_list_values[k][field] != null, false)
    ]]))
    error_message = "Cluster override_defaults must name a supported collection path with an explicit non-null local value: defined_tags, freeform_tags, options.persistent_volume_config.defined_tags/freeform_tags, options.service_lb_config.defined_tags/freeform_tags, networking.api_endpoint_nsg_ids, or image_signing.kms_key_ids. Use {} or [] to clear."
  }
}
