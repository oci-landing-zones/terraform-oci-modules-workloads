# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

output "instances" {
  description = "The Compute instances"
  value       = var.enable_output ? oci_core_instance.these : null
}

output "private_ips" {
  description = "The private IPs"
  value = var.enable_output ? oci_core_private_ip.these : null
}

output "secondary_vnics" {
  description = "The secondary VNICs"
  value = var.enable_output ? data.oci_core_vnic.these : null
}

output "secondary_vnic_attachments" {
  description = "The secondary VNIC attachments"
  value = var.enable_output ? oci_core_vnic_attachment.these : null
}

output "secondary_private_ips" {
  description = "The secondary private IPs in all instances VNICs"
  value = var.enable_output ? oci_core_private_ip.these : null
}

output "block_volumes" {
  description = "The block volumes"
  value       = var.enable_output ? oci_core_volume.these : null
}

output "file_systems" {
  description = "The file systems"
  value       = var.enable_output ? oci_file_storage_file_system.these : null
}

output "file_systems_mount_targets" {
  value       = var.enable_output ? oci_file_storage_mount_target.these : null
}

output "file_systems_snapshot_policies" {
  value       = var.enable_output ? oci_file_storage_filesystem_snapshot_policy.these : null
}

output "cluster_networks" {
  description = "The cluster networks."
  value       = var.enable_output ? oci_core_cluster_network.these : null
}

output "compute_clusters" {
  description = "The Compute clusters."
  value       = var.enable_output ? oci_core_compute_cluster.these : null
}

output "oci_core_app_catalog_listing_resource_version" {
  value = data.oci_core_app_catalog_listing_resource_version.this
}

output "oci_core_app_catalog_listings" {
  value = data.oci_core_app_catalog_listings.these
}

output "oci_core_app_catalog_listing_resource_versions" {
  value = data.oci_core_app_catalog_listing_resource_versions.these
}

output "all_oci_core_app_catalog_listings" {
  value = data.oci_core_app_catalog_listings.all
}
