terraform {
  required_version = ">= 1.4.0"
}

# Configuration normalization is deliberately provider-free.
output "contract" {
  value = {
    cluster_configuration   = var.cluster_configuration
    workers_configuration   = var.workers_configuration
    compartments_dependency = var.compartments_dependency
    network_dependency      = var.network_dependency
    kms_dependency          = var.kms_dependency
    enable_output           = var.enable_output
    module_name             = var.module_name
  }
}
