# CIS OCI Native CNI, Enhanced OKE and Virtual Node Pool Example 

## Introduction

This example shows how to deploy Kubernetes Clusters and Virtual Node Pools in OCI using the [cis-oke module](../../).
Virtual Node Pools only work on Enhanced Clusters with Native CNI.
It deploys:
   - One Enhanced Kubernetes Cluster (OKE1) with Native CNI which has only the required attributes.
   - One commented Kubernetes Cluster with all the attributes available.
   - One Virtual Node Pool which has only the required attributes.
   - One commented Virtual Node Pool with all the attributes available.


The Kubernetes Clusters and Virtual Node Pools with the following characteristics:

OKE1:
- The Cluster will be a an Enhanced Cluster as defined by *is_enhanced* attribute.
- The Cluster will have the native cni as defined in the *cni_type* attribute.
- The Cluster will have the latest kubernetes version by default.
- The cluster will have a private api endpoint by default.

VIRTUAL_NODEPOOL1:
- The virtual node pool will be created in OKE1 Cluster.
- It will be created in the same compartment as the OKE1 Cluster.
- It will have three virtual worker nodes.
- The pods will use the "Pod.Standard.E4.Flex" shape as defined by the *pod_shape* attribute.



Commented NODEPOOL2:
- The virtual node pool will be created in OKE1 Cluster.
- It will be created in the same compartment as the OKE1 Cluster.
- It will have three virtual worker nodes.
- The pods will use the "Pod.Standard.E4.Flex" shape as defined by the *pod_shape* attribute.
- The virtual nodes will be placed as following: Vnode1 in ad1 and fd1, Vnode2 in ad2 and fd2 and lastly Vnode3 will be placed in ad1 and fd2 as defined in the *placement* map.
- The virtual nodes will have the *NoSchedule* effect.


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

