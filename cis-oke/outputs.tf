output "cluster" {
  description = "The single OKE cluster, read back from OCI."
  value       = var.enable_output && var.cluster_configuration != null ? data.oci_containerengine_cluster.managed[local.cluster_key] : null
}

output "node_pools" {
  description = "Managed OKE pools keyed by Landing Zone identity."
  value       = var.enable_output ? { for k, p in local.pools : k => module.cluster[local.cluster_key].worker_pools[coalesce(p.name, k)] if p.mode == "node-pool" } : null
}
output "virtual_node_pools" {
  description = "Virtual OKE pools keyed by Landing Zone identity."
  value       = var.enable_output ? { for k, p in local.pools : k => module.cluster[local.cluster_key].worker_pools[coalesce(p.name, k)] if p.mode == "virtual-node-pool" } : null
}
output "nodes" {
  description = "Managed nodes by pool identity and node name; retains legacy enable_output behavior."
  value       = { for k, p in local.pools : k => { for n in module.cluster[local.cluster_key].worker_pools[coalesce(p.name, k)].nodes : n.name => n } if p.mode == "node-pool" }
}
