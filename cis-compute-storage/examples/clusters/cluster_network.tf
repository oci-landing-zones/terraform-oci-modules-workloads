# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

locals {

    cluster_network_configuration = (var.cluster_type == "cluster_network") ? {
        clusters = {
            "CLUSTER-NETWORK" = { # cluster_network
                name = var.cluster_name
                type = var.cluster_type
                compartment_id = var.cluster_compartment_id
                availability_domain = substr(var.cluster_ad,-1,-1)
                cluster_network_settings = {
                    instance_configuration_id = "INSTANCE-CONFIG"
                    instance_pool = {
                        size = var.cluster_network_pool_size
                        name = var.cluster_network_pool_name
                    }
                    networking = {
                        subnet_id = var.cluster_network_subnet_id
                        ipv6_enable = var.cluster_network_ipv6_cidrs_enable
                        ipv6_subnet_cidrs = var.cluster_network_ipv6_cidrs
                        secondary_vnic_settings = var.cluster_network_secondary_vnic_enable ? {
                            subnet_id = var.cluster_network_secondary_vnic_subnet_id                     
                            name = var.cluster_network_secondary_vnic_name                   
                            ipv6_enable = var.cluster_network_secondary_vnic_ipv6_cidrs_enable              
                            ipv6_subnet_cidrs = var.cluster_network_secondary_vnic_ipv6_cidrs
                        } : null
                    }
                }
            }  
        }
    } : null 
    
    cluster_network_instances_configuration = var.cluster_type == "cluster_network" ? {
        configurations = {
            "INSTANCE-CONFIG" = { # cluster_network configuration
                compartment_id = var.cluster_compartment_id
                name = "${var.cluster_name}-instance-configuration"
                template_instance_id = lower(var.cluster_network_source) == "existing_instance" ? var.cluster_network_source_instance_id : "CLUSTER-NETWORK-INSTANCE"
                # instance_details = var.cluster_network_source == "image" ? {
                #     shape          = var.cluster_network_source_image_shape
                #     source_type    = "image"
                #     image_id       = var.cluster_network_source_image_id
                #     compartment_id = var.cluster_compartment_id
                # } : null   
            }
        }
    } : null

    cluster_network_compute_instances_configuration = var.cluster_type == "cluster_network" ? {
        default_compartment_id = var.cluster_compartment_id
        default_subnet_id = var.cluster_network_subnet_id 
        #default_ssh_public_key_path = "~/.ssh/id_rsa.pub"
        instances = {
            "CLUSTER-NETWORK-INSTANCE" = {
                shape = var.cluster_network_source_image_shape
                name  = "${var.cluster_name}-instance"
                placement = {
                    availability_domain = substr(var.cluster_ad,-1,-1)
                    fault_domain = 2
                }
                boot_volume = {
                    size = 120
                    preserve_on_instance_deletion = false
                }
                networking = {
                    hostname  = "${var.cluster_name}-instance"
                    #network_security_groups = ["ocid1.networksecuritygroup.oc1.phx.aaaaaaaaqbsj3tqlzaefdoyhoz54uxlryd3sh2lag4cnvaj2hfk5pav7woua"]
                }
                image = {
                    id = var.cluster_network_source_image_id
                }
            }
        }
    } : null
}

module "cluster_network" {
  count = var.cluster_type == "cluster_network" ? 1 : 0
  source = "../.."
  providers = {
    oci = oci
    oci.block_volumes_replication_region = oci
  }
  clusters_configuration = local.cluster_network_configuration
  cluster_instances_configuration = local.cluster_network_instances_configuration
  instances_configuration = local.cluster_network_compute_instances_configuration
}