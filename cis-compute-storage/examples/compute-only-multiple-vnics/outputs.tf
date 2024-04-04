
# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

output "instances" {
  description = "The instances"
  value       = module.compute.instances
}

output "secondary_vnics" {
  description = "The secondary VNICs"
  value       = module.compute.secondary_vnics
}

output "secondary_vnic_attachments" {
  description = "The secondary VNIC attachments"
  value       = module.compute.secondary_vnic_attachments
}

output "secondary_private_ips" {
  description = "The secondary private IP addresses"
  value       = module.compute.secondary_private_ips
}