# OKE Native Basic Example 

## Introduction

This example shows how to deploy Kubernetes clusters and node pools in OCI using the [cis-oke module](https://github.com/oracle-quickstart/terraform-oci-secure-workloads/tree/main/cis-oke). It deploys Native-based basic OKE cluster and one node pool with the characteristics described below. 

This example provides no cluster access automation. Automating access to the cluster can be implemented with the [OCI Bastion service module](https://github.com/oracle-quickstart/terraform-oci-cis-landing-zone-security/tree/main/bastion). See the [available examples](https://github.com/oracle-quickstart/terraform-oci-cis-landing-zone-security/tree/main/bastion/examples).

As alternatives to this example, the following examples are available with full cluster access automation:
   1. [OKE Native with Localhost Access Example](../private-cluster-access-via-localhost/), where the OKE cluster is managed from a host external to OCI (like the user laptop). 
   2. [OKE Native with Operator Access Example](../private-cluster-access-via-operator/), where the OKE cluster is managed from a Compute instance deployed in OCI. 

### Pre-Requisite

The OKE cluster and the Node Pool depend on a pre existing Virtual Cloud Network (VCN). A VCN built specifically for this deployment is available in [native network example](https://github.com/oracle-quickstart/terraform-oci-cis-landing-zone-networking/tree/main/examples/oke-examples/native).

### Resources Deployed by this Example

OKE Cluster (OKE1):
- The Cluster will be a Basic Cluster.
- The Cluster will have the native cni as defined in the *cni_type* attribute.
- The Cluster will have the latest kubernetes version by default.
- The cluster will have a private api endpoint by default.

Node Pool (NODEPOOL1):
- The nodepool will be created in OKE1 Cluster.
- The nodes will be created in the same compartment as the OKE1 Cluster.
- The nodes will have the same kubernetes version as the OKE1 Cluster.
- The nodepool will have three worker nodes.
- The nodes will use the "VM.Standard.E4.Flex" shape as defined by the *node_shape* attribute.
- The nodes will use the image specified in the *image* attribute.
- The nodes will have 16 GB memory and 1 ocpu by default.
- The nodes boot volume size will be 60GB and will be terminated when the nodes are destroyed by default.

Commented Virtual Node Pool (VIRTUAL_POOL1):
- The virtual node pool will be created in OKE1 Cluster.
- It will be created in the same compartment as the OKE1 Cluster.
- It will have three virtual worker nodes.
- The pods will use the "Pod.Standard.E4.Flex" shape as defined by the *pod_shape* attribute.

### How to create Virtual Node Pools

To create Virtual Node Pools you need to make the cluster enhanced by setting the attribute **is_enhanced** to **true** and uncomment the **virtual_node_pools** map.
Virtual Node Pools only work on enhanced clusters.

To create **only** Virtual Node Pools, comment/remove the **node_pools** map.

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

## Accessing the Cluster

Managing Kubernetes applications in OCI includes the ability to invoke OKE API endpoint and SSH'ing into worker nodes. 
As the endpoint and worker nodes are in private subnets, access can be enabled through the OCI Bastion service or via a jump host that is deployed in a public subnet. 

### Access via OCI Bastion Service
- **OKE API endpoint**: Cluster access is enabled by configuring a *kubeconfig* file and setting up the OCI Bastion service endpoint with a Port Forwarding session. [More information](https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengsettingupbastion.htm). 
- **Worker nodes**: SSH access to worker nodes (\*) is enabled by setting up OCI Bastion service endpoint with a Managed SSH session. [More information](https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengsettingupbastion.htm).

Utilize the [OCI Bastion service module](https://github.com/oracle-quickstart/terraform-oci-cis-landing-zone-security/tree/main/bastion) to automate OCI Bastion service.

(\*) SSH access to worker nodes via the OCI Bastion service requires the Cloud Agent Bastion plugin enabled in the worker nodes.

