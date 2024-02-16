# Copyright (c) 2023 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

module "oke" {
  source                 = "../../../"
  clusters_configuration = var.clusters_configuration
  workers_configuration  = var.workers_configuration
}

module "bastion" {
  source                 = "../../../../../terraform-oci-cis-landing-zone-security/bastion-service/"
  bastions_configuration = var.bastions_configuration
  sessions_configuration = var.sessions_configuration
  clusters_dependency    = module.oke.clusters
}

data "oci_containerengine_cluster_kube_config" "kube_config" {
  for_each      = var.clusters_configuration != null ? var.clusters_configuration["clusters"] : {}
  cluster_id    = module.oke.clusters[each.key].id
  token_version = "2.0.0"
}

resource "null_resource" "create_local_kubeconfig" { # This null resource is used to create a local file to store the kube config to allow port forward connection to the OKE API Endpoint.
  for_each = var.clusters_configuration != null ? var.clusters_configuration["clusters"] : {}
  provisioner "local-exec" {
    command = "echo '${tostring(replace(data.oci_containerengine_cluster_kube_config.kube_config[each.key].content, split(":", module.oke.clusters[each.key].endpoints[0].private_endpoint)[0], "127.0.0.1"))}' >> ${path.root}/kubeconfig"
  }
}
