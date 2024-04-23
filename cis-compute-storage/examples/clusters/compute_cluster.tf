# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

locals {

    compute_cluster_configuration = (var.cluster_type == "compute") ? {
        clusters = {
            "COMPUTE-CLUSTER" = { # compute cluster
                name = var.cluster_name
                type = var.cluster_type
                compartment_id = var.cluster_compartment_id
                availability_domain = substr(var.cluster_ad,-1,-1)
            }       
        }
    } : null

    compute_cluster_instances_configuration = var.cluster_type == "compute" ? {
        default_compartment_id = var.cluster_compartment_id
        default_subnet_id = var.compute_cluster_subnet_id 
        #default_ssh_public_key_path = "~/.ssh/id_rsa.pub"
        instances = {for i in range(1,var.compute_cluster_size+1) : "COMPUTE-CLUSTER-INSTANCE-${i}" => { # compute cluster instances
            shape = var.compute_cluster_source_image_shape
            name  = "${var.cluster_name}-instance-${i}"
            cluster_id = "COMPUTE-CLUSTER"
            placement = {
                availability_domain = substr(var.cluster_ad,-1,-1)
                fault_domain = 2
            }
            boot_volume = {
                size = 120
                preserve_on_instance_deletion = false
            }
            networking = {
                hostname  = "${var.cluster_name}-instance-${i}"
                network_security_groups = [var.compute_cluster_nsg_id]
            }
            image = {
                id =var.compute_cluster_source_image_id
            }
        }}
    } : null
}

module "compute_cluster" {
  count = var.cluster_type == "compute" ? 1 : 0
  source = "../.."
  providers = {
    oci = oci
    oci.block_volumes_replication_region = oci
  }
  clusters_configuration = local.compute_cluster_configuration
  instances_configuration = local.compute_cluster_instances_configuration
}