terraform {
  required_version = ">= 1.5.0, < 1.6.0"
}

# These outputs make schema conversion/default behavior observable in test plans.
# This prototype performs no provisioning and does not resolve dependency maps.
output "contract" {
  value = {
    clusters_configuration  = var.clusters_configuration
    workers_configuration   = var.workers_configuration
    compartments_dependency = var.compartments_dependency
    network_dependency      = var.network_dependency
    kms_dependency          = var.kms_dependency
    enable_output           = var.enable_output
    module_name             = var.module_name
  }
}
