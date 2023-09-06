
# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

output "instances" {
  description = "The instances"
  value       = module.compute.instances
}

output "block_volumes" {
  description = "The block volumes"
  value       = module.compute.block_volumes
}

output "file_systems" {
  description = "The file systems"
  value       = module.compute.file_systems
}
