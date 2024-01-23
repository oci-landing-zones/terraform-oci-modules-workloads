# CIS OCI Native CNI OKE and Node Pool Example 

## Introduction

This example shows how to deploy Kubernetes Clusters and Node Pools in OCI using the [cis-oke module](../../).
It deploys:
   - One Native CNI Kubernetes Cluster (OKE1) which has only the required attributes.
   - One commented Native CNI Kubernetes Cluster with all the attributes available.
   - One Node Pool which has only the required attributes for a Native CNI Cluster.
   - One commented Node Pool with all the attributes available.


The Kubernetes Clusters and Node Pools with the following characteristics:

OKE1:
- The Cluster will be a Basic Cluster by default.
- The Cluster will have the native cni as defined in the *cni_type* attribute.
- The Cluster will have the latest kubernetes version by default.
- The cluster will have a private api endpoint by default.

Commented OKE2:
- The Cluster will be an Enhanced Cluster as defined by *is_enhanced* attribute.
- The Cluster will have the native cni as defined in the *cni_type* attribute.
- The Cluster will have the latest kubernetes version since the attribute *kubernetes_version* is set to null.
- The cluster will have a private api endpoint as defined in *public_endpoint* attribute.


NODEPOOL1:
- The nodepool will be created in OKE1 Cluster.
- The nodes will be created in the same compartment as the OKE1 Cluster.
- The nodes will have the same kubernetes version as the OKE1 Cluster.
- The nodepool will have three worker nodes.
- The nodes will use the "VM.Standard.E4.Flex" shape as defined by the *node_shape* attribute.
- The nodes will use the image specified in the *image* attribute.
- The nodes will have 16 GB memory and 1 ocpu by default.
- The nodes boot volume size will be 60GB and will be terminated when the nodes are destroyed by default.
- The nodes will be placed as following: node1 in ad1 and fd1, node2 in ad1 and fd2 and lastly node3 will be placed in ad1 and fd3 by default.

Commented NODEPOOL2:
- The nodepool will be created in OKE1 Cluster.
- The nodes will have the same kubernetes version as the OKE1 Cluster, since the attribute *kubernetes_version* is set to null.
- The nodepool will have three worker nodes.
- The nodes will use the "VM.Standard.E4.Flex" shape as defined by the *node_shape* attribute.
- The nodes will use the latest OKE *Oracle Linux 8.8* image available for the kubernetes version of the nodepool as defined by *image* attribute.
- The nodes will have 16 GB memory and 1 ocpu by default as defined in the *flex_shape_settings* map.
- The nodes boot volume size will be 60GB and will be terminated when the nodes are destroyed by default as defined in the *boot_volume* map.
- The nodes will be placed as following: node1 in ad1 and fd1, node2 in ad2 and fd2 and lastly node3 will be placed in ad1 and fd2 as defined in the *placement* map.


See [input.auto.tfvars.template](./input.auto.tfvars.template) for the variables configuration.

## Using this example
1. Rename *input.auto.tfvars.template* to *\<project-name\>.auto.tfvars*, where *\<project-name\>* is any name of your choice.

2. Within *\<project-name\>.auto.tfvars*, provide tenancy connectivity information and adjust the input variables, by making the appropriate substitutions:
   - Replace \<REPLACE-BY-\*\> placeholders with appropriate values. 
   
Refer to [cis-oke module README.md](../../README.md) for overall attributes usage.

3. In this folder, run the typical Terraform workflow:
```
terraform init
terraform plan -out plan.out
terraform apply plan.out
```

## Managing OKE Resources
Accessing the Kubernetes API endpoint and the worker nodes differs depending on whether they're in a private or public subnet.

### Public
- API endpoint
   The Cluster access can be enabled by setting up the kubeconfig file. [More information](https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengdownloadkubeconfigfile.htm).
- Workers
   The ssh access to worker nodes is enabled by adding your public ssh key on them. [More information](https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengconnectingworkernodesusingssh.htm).  
### Private
- API endpoint
   The Cluster access can be enabled by setting up a Bastion Service with a port forwarding Bastion session.[More information](https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengsettingupbastion.htm).
- Workers
   The ssh access to worker nodes is enabled by setting up a Bastion Service with a managed Bastion session.[More information](https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengsettingupbastion.htm).

