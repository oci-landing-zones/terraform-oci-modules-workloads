# CIS OCI RDMA Cluster Networks Example

## Introduction
This example shows how to deploy RDMA cluster networks in OCI using the [cis-compute-storage module](../../). It deploys one Compute instance, one cluster instance configuration, and one cluster network with the characteristics described below. Refer to [input.auto.tfvars.template](./input.auto.tfvars.template) for the variables configuration.

### Compute Instance
- The deployed Compute instance is used as a template for the cluster instance configuration.
- The Compute instance shape is "BM.Optimized3.36".
- The Compute instance is created in the compartment and subnet specified by *default_compartment_id* and *default_subnet_id* attributes, respectively, within *instances_configuration* variable.

Note that you must provide the image *name* and *publisher_name* for provisioning the Compute instance. Use the [marketplace-images module](../../../marketplace-images/) to obtain Marketplace images information based on a search filter. It will also return the image OCID that can be used instead of the image name/publisher pair.

### Cluster Instance Configuration
- A cluster instance configuration is created based on the Compute instance. This is indicated by *template_instance_id* attribute within *rdma_cluster_instances_configuration* variable.
- The cluster instance configuration is created in the compartment specified by *default_compartment_id* attribute within *rdma_cluster_instances_configuration* variable.

### Cluster Instance Pool
- A cluster instance pool is created based on the provided cluster instance configuration.

### RDMA Cluster Network
- An RDMA cluster network with one cluster instance pool of size 1.
- The cluster instance pool size is specified by *instance_pool size* attribute within *rdma_clusters_configuration* variable.
- The cluster network is created in the compartment specified by *default_compartment_id* attribute within *rdma_clusters_configuration* variable.

## Using this example
1. Rename *input.auto.tfvars.template* to *\<project-name\>.auto.tfvars*, where *\<project-name\>* is any name of your choice.

2. Within *\<project-name\>.auto.tfvars*, provide tenancy connectivity information and adjust the input variables, by making the appropriate substitutions:
   - Replace \<REPLACE-BY-\*\> placeholders with appropriate values. 
   
Refer to [cis-compute-storage module README.md](../../README.md) for overall attributes usage.

3. In this folder, run the typical Terraform workflow:
```
terraform init
terraform plan -out plan.out
terraform apply plan.out
```