
# Copyright (c) 2023 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

module "cluster_networks" {
  source = "../.."
  providers = {
    oci = oci
    oci.block_volumes_replication_region = oci
  }
  clusters_configuration = var.clusters_configuration
  cluster_instances_configuration = var.cluster_instances_configuration
  instances_configuration = var.instances_configuration
}
