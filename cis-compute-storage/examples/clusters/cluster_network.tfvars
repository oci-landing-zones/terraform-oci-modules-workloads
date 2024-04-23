# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

tenancy_ocid         = "<TENANCY_OCID>"
user_ocid            = "<USER_OCID>"
fingerprint          = "<PEM_KEY_FINGERPRINT>"
private_key_path     = "<PATH_TO_PRIVATE_KEY>"
private_key_password = "<PRIVATE_KEY_PASSWORD>"
region               = "<TENANCY_REGION>"

## Cluster Network basic parameters
cluster_compartment_id = "<CLUSTER_COMPARTMENT_OCID>"
cluster_ad = "1"
cluster_type = "cluster_network"
cluster_name = "my-cluster"
cluster_network_pool_name = "my-cluster-network-pool"
cluster_network_pool_size = 2
cluster_network_subnet_id = "<CLUSTER_SUBNET_OCID>"

## Cluster network image parameters 
cluster_network_source = "image" # Use "existing_instance" for creating the cluster members based on a existing instance.
cluster_network_source_image_id = "ocid1.image.oc1.phx.aaaaaaaa7nt27n7ep5gsbcp5e6shrkof6lj5vympxh6epcyy7t3jbslukdda" # Oracle-Linux-7.9-2024.03.28-0.  Change to any other supported image OCID. 
cluster_network_source_image_shape = "BM.Optimized3.36" # Supported shapes listed in https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/managingclusternetworks.htm#supported-shapes

## Cluster network existing instance template.
cluster_network_source_instance_id = "<EXISTING_INSTANCE_OCID>" # Only applicable if cluster_network_source = "existing_instance"

## Cluster network secondary parameters. All optional.
cluster_network_ipv6_cidrs_enable = false
cluster_network_ipv6_cidrs = []
cluster_network_secondary_vnic_enable = false
cluster_network_secondary_vnic_name = null
cluster_network_secondary_vnic_vcn_compartment_id = null
cluster_network_secondary_vnic_vcn_id = null
cluster_network_secondary_vnic_subnet_id = null
cluster_network_secondary_vnic_ipv6_cidrs_enable = false
cluster_network_secondary_vnic_ipv6_cidrs = []