# OKE Flannel Basic Example 

## Introduction

This example shows how to deploy Kubernetes clusters and node pools in OCI using the [cis-oke module](https://github.com/oracle-quickstart/terraform-oci-secure-workloads/tree/main/cis-oke). It deploys Flannel-based basic OKE cluster and one node pool with the characteristics described below. No cluster access automation is provided.

### Pre-Requisite

The OKE cluster and the Node Pool depend on a pre existing Virtual Cloud Network (VCN). A VCN built specifically for this deployment is available in [flannel network example](https://github.com/oracle-quickstart/terraform-oci-cis-landing-zone-networking/tree/main/examples/oke-examples/flannel).

### Resources Deployed by this Example

OKE Cluster (OKE1):
- It will have the latest kubernetes version by default.
- It will have the Flannel CNI by default.
- It will have a private API endpoint by default.

Node Pool (NODEPOOL1):
- The node pool will be created in OKE Cluster.
- The nodes will be created in the same compartment as the OKE Cluster.
- The nodes will have the same Kubernetes version as the OKE Cluster.
- The node pool will have three worker nodes.
- The nodes will use the "VM.Standard.E4.Flex" shape as defined by the *node_shape* attribute.
- The nodes will have 16 GB memory and 1 OCPU by default.
- The nodes boot volume size will be 60GB and will be terminated when the nodes are destroyed by default.
- The nodes will be placed as following: node 1 in availability domain 1 (AD1) and fault domain 1 (FD1), node 2 in AD1/FD2, and lastly, node 3 will be placed in AD1/FD3 by default.

See [input.auto.tfvars.template](./input.auto.tfvars.template) for the variables configuration.

## Using this example
1. Rename *input.auto.tfvars.template* to *\<project-name\>.auto.tfvars*, where *\<project-name\>* is any name of your choice.

2. Within *\<project-name\>.auto.tfvars*, provide tenancy connectivity information and adjust the input variables, by making the appropriate substitutions:
   - Replace \<REPLACE-BY-\*\> placeholders with appropriate values. 
   
Refer to [cis-oke module README.md](https://github.com/oracle-quickstart/terraform-oci-secure-workloads/tree/main/cis-oke/README.md) for overall attributes usage.

3. In this folder, run the typical Terraform workflow:
```
terraform init
terraform plan -out plan.out
terraform apply plan.out
```

## Accessing the Cluster

Managing Kubernetes applications in OCI includes the ability to invoke OKE API endpoint and SSH'ing into Worker nodes. 
Invoking the OKE API endpoint and accessing worker nodes differs depending on whether they are in a private or public subnet:

### Private (as in this example)
- **API endpoint**: Cluster access is enabled by configuring a Kube config file and setting up the OCI Bastion service with a Port Forwarding session. [More information](https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengsettingupbastion.htm). 
- **Workers**: SSH access to worker nodes (\*) is enabled by setting up OCI Bastion service endpoint with a Managed SSH session. [More information](https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengsettingupbastion.htm).

(\*) SSH access to worker nodes via the OCI Bastion service requires the Cloud Agent Bastion plugin enabled in the worker nodes.

An option to OCI Bastion service is a jump host that you deploy and manage in a public subnet.

### Public
- **API endpoint**: Cluster access is enabled by configuring a Kube config file. [More information](https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengdownloadkubeconfigfile.htm).
- **Workers**: SSH access to worker nodes is enabled by adding your public SSH key on them. [More information](https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengconnectingworkernodesusingssh.htm). 

