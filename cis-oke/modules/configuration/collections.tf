# A single cluster has explicit collections; shared defaults belong to the caller.
locals {
  configured_clusters = var.cluster_configuration == null ? {} : { "cluster" = var.cluster_configuration }
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
    maps  = { for field, value in local.cluster_map_values[k] : field => coalesce(value, {}) }
    lists = { for field, value in local.cluster_list_values[k] : field => distinct(coalesce(value, [])) }
  } }
}
output "cluster_collections" {
  value = local.cluster_collections
}
