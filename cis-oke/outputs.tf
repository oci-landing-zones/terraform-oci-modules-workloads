# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

output "clusters" {
  description = "The Kubernetes Clusters"
  value       = var.enable_output ? oci_containerengine_cluster.these : null
}

output "node_pools" {
  description = "The OKE Node Pools"
  value       = var.enable_output ? oci_containerengine_node_pool.these : null
}

output "virtual_node_pools" {
  description = "The OKE Virtual Node Pools"
  value       = var.enable_output ? oci_containerengine_virtual_node_pool.these : null
}