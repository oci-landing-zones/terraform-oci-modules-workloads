# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

output "instances" {
  description = "The Compute instances"
  value       = var.enable_output ? oci_core_instance.this : null
}

output "block_volumes" {
  description = "The block volumes"
  value       = var.enable_output ? oci_core_volume.block : null
}

output "file_systems" {
  description = "The file systems"
  value       = var.enable_output ? oci_file_storage_file_system.this : null
}
