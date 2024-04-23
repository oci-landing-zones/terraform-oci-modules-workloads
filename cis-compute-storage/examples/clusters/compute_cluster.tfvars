# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

tenancy_ocid         = "<TENANCY_OCID>"
user_ocid            = "<USER_OCID>"
fingerprint          = "<PEM_KEY_FINGERPRINT>"
private_key_path     = "<PATH_TO_PRIVATE_KEY>"
private_key_password = "<PRIVATE_KEY_PASSWORD>"
region               = "<TENANCY_REGION>"

## Compute cluster basic parameters
cluster_compartment_id = "<CLUSTER_COMPARTMENT_OCID>"
cluster_ad = "1"
cluster_type = "compute"
cluster_name = "my-cluster"
compute_cluster_size = 2

## Compute cluster image parameters
compute_cluster_source_image_id = "ocid1.image.oc1.phx.aaaaaaaa7nt27n7ep5gsbcp5e6shrkof6lj5vympxh6epcyy7t3jbslukdda" # Oracle-Linux-7.9-2024.03.28-0. Change to any other supported image OCID.  
compute_cluster_source_image_shape = "BM.Optimized3.36"

## Compute cluster networking parameters
compute_cluster_subnet_id = "<CLUSTER_SUBNET_OCID>"
compute_cluster_nsg_id = "<CLUSTER_NSG_OCID>" # optional. Omit or assign null for no NSGs.