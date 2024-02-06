
# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

# output "instances" {
#   description = "The instances"
#   value       = module.compute.instances
# }


output "clusters" {
  value = module.oke.clusters
}

output "virtual_node_pools" {
  value = module.oke.virtual_node_pools
}
