# OCI Landing Zones Compute Module - Compute Cluster Example

## Introduction
This example shows how to deploy Compute clusters in OCI using the [OCI Landing Zones Compute module](../../README.md). It deploys one Compute instance, one cluster instance configuration, and one cluster network with the characteristics described below. Refer to [input.auto.tfvars.template](./input.auto.tfvars.template) for the variables configuration.

A [Compute cluster](https://docs.oracle.com/iaas/Content/Compute/Tasks/compute-clusters.htm) is a remote direct memory access (RDMA) network group. You can create high performance computing (HPC) instances in the network and manage them individually.

### Compute Instance
- The deployed Compute instance is used as a template for the cluster instance configuration.
- The Compute instance shape is "BM.Optimized3.36".
- The Compute instance is created in the compartment and subnet specified by *default_compartment_id* and *default_subnet_id* attributes, respectively, within *instances_configuration* variable.

Note that you must provide the marketplace image *name* for provisioning the Compute instance. Use the [marketplace-images module](../../../marketplace-images/) to obtain Marketplace images information based on a search filter.

### Cluster Instance Configuration
- A cluster instance configuration is created based on the Compute instance. This is indicated by *template_instance_id* attribute within *cluster_instances_configuration* variable.
- The cluster instance configuration is created in the compartment specified by *default_compartment_id* attribute within *cluster_instances_configuration* variable.

### Cluster Instance Pool
- A cluster instance pool is created based on the provided cluster instance configuration.

### RDMA Cluster Network
- An RDMA cluster network with one cluster instance pool of size 1.
- The cluster instance pool size is specified by *instance_pool size* attribute within *clusters_configuration* variable.
- The cluster network is created in the compartment specified by *default_compartment_id* attribute within *clusters_configuration* variable.

## Using this example
1. Rename *input.auto.tfvars.template* to *\<project-name\>.auto.tfvars*, where *\<project-name\>* is any name of your choice.

2. Within *\<project-name\>.auto.tfvars*, provide tenancy connectivity information and adjust the input variables, by making the appropriate substitutions:
   - Replace \<REPLACE-WITH-\*\> placeholders with appropriate values. 
   
Refer to [Compute/Storage module README.md](../../README.md) for overall attributes usage.

3. In this folder, run the typical Terraform workflow:
```
terraform init
terraform plan -out plan.out
terraform apply plan.out
```