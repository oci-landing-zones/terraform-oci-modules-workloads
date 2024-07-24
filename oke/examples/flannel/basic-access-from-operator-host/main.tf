# Copyright (c) 2023 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

module "oke" {
  source                 = "../../../"
  clusters_configuration = var.clusters_configuration
  workers_configuration  = var.workers_configuration
}

module "operator_instance" {
  source = "github.com/oracle-quickstart/terraform-oci-secure-workloads//compute-storage?ref=v0.1.3"
  providers = {
    oci                                  = oci
    oci.block_volumes_replication_region = oci
  }
  instances_configuration = var.instances_configuration
}

module "bastion" {
  depends_on = [module.oke]
  source                 = "github.com/oracle-quickstart/terraform-oci-cis-landing-zone-security.git//bastion?ref=v0.1.4"
  bastions_configuration = var.bastions_configuration
  sessions_configuration = var.sessions_configuration
  instances_dependency   = module.operator_instance.instances
}

data "oci_containerengine_cluster_kube_config" "kube_config" {
  for_each      = var.clusters_configuration != null ? var.clusters_configuration["clusters"] : {}
  cluster_id    = module.oke.clusters[each.key].id
  token_version = "2.0.0"
}

resource "null_resource" "add_kubeconfig" { # This null resource is used to add the kube config on the Operator instance using the Bastion Session.
  for_each = var.sessions_configuration["sessions"]
  provisioner "local-exec" {
    command = format("%s %s", replace(replace(replace(replace(module.bastion.sessions[each.key], "\"", "'"), "<privateKey>", var.ssh_private_key), "-o ProxyCommand", "-o StrictHostKeyChecking=no -o ProxyCommand"), "-W", "-o StrictHostKeyChecking=no -W"), "-y -x 'mkdir ~/.kube/'")
    
  }
  provisioner "local-exec" {
    command = format("%s %s", replace(replace(replace(replace(module.bastion.sessions[each.key], "\"", "'"), "<privateKey>", var.ssh_private_key), "-o ProxyCommand", "-o StrictHostKeyChecking=no -o ProxyCommand"), "-W", "-o StrictHostKeyChecking=no -W"), "-y -x 'echo \"${join(",", [for cluster in data.oci_containerengine_cluster_kube_config.kube_config : tostring(cluster.content)])}\" >> ~/.kube/config'")
  }
}

data "local_file" "existing" {
  filename = "${path.module}/install_kubectl.sh"
}

resource "null_resource" "install_kubect" { # This null resource is used to install the kubectl and set the Operator instance OCI authentication to Instance Principal.
  for_each = var.sessions_configuration["sessions"]
  provisioner "local-exec" {
    command = format("%s %s", replace(replace(replace(replace(module.bastion.sessions[each.key], "\"", "'"), "<privateKey>", var.ssh_private_key), "-o ProxyCommand", "-o StrictHostKeyChecking=no -o ProxyCommand"), "-W", "-o StrictHostKeyChecking=no -W"), "-y -x '${data.local_file.existing.content}'")
  }
}