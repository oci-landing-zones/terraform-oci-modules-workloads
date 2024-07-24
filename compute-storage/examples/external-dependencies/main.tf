
# Copyright (c) 2023 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

data "oci_objectstorage_namespace" "this" {
  count = var.oci_compartments_dependency != null ? 1 : 0
    compartment_id = var.tenancy_ocid
}

data "oci_objectstorage_object" "compartments" {
  count = var.oci_compartments_dependency != null ? 1 : 0
    bucket    = var.oci_compartments_dependency.bucket
    namespace = data.oci_objectstorage_namespace.this[0].namespace
    object    = var.oci_compartments_dependency.object
}

data "oci_objectstorage_object" "network" {
  count = var.oci_network_dependency != null ? 1 : 0
    bucket    = var.oci_network_dependency.bucket
    namespace = data.oci_objectstorage_namespace.this[0].namespace
    object    = var.oci_network_dependency.object
}

data "oci_objectstorage_object" "kms" {
  count = var.oci_kms_dependency != null ? 1 : 0
    bucket    = var.oci_kms_dependency.bucket
    namespace = data.oci_objectstorage_namespace.this[0].namespace
    object    = var.oci_kms_dependency.object
}

data "oci_objectstorage_object" "compute" {
  count = var.oci_compute_dependency != null ? 1 : 0
    bucket    = var.oci_compute_dependency.bucket
    namespace = data.oci_objectstorage_namespace.this[0].namespace
    object    = var.oci_compute_dependency.object
}


module "compute" {
  source = "../.."
  providers = {
    oci = oci
    oci.block_volumes_replication_region = oci.block_volumes_replication_region
  }
  instances_configuration = var.instances_configuration
  storage_configuration   = var.storage_configuration
  compartments_dependency = var.oci_compartments_dependency != null ? jsondecode(data.oci_objectstorage_object.compartments[0].content) : null
  network_dependency = var.oci_network_dependency != null ? jsondecode(data.oci_objectstorage_object.network[0].content) : null
  kms_dependency = var.oci_network_dependency != null ? jsondecode(data.oci_objectstorage_object.kms[0].content) : null
  instances_dependency = var.oci_compute_dependency != null ? jsondecode(data.oci_objectstorage_object.compute[0].content) : null
}
