output "instances" {
  description = "The Compute instances"
  value       = {for k, v in module.compute.instances : k => {id: v.id}}
}

output "oci_core_app_catalog_listing_resource_version" {
  value = module.compute.oci_core_app_catalog_listing_resource_version
}

output "oci_marketplace_accepted_agreement" {
  value = module.compute.oci_marketplace_accepted_agreement
}

output "oci_marketplace_listing_package_agreement" {
  value = module.compute.oci_marketplace_listing_package_agreement
}