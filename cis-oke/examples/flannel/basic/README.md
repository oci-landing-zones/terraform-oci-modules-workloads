# OKE Flannel Basic Example 

## Introduction

This example shows how to deploy Kubernetes clusters and node pools in OCI using the [cis-oke module](https://github.com/oracle-quickstart/terraform-oci-secure-workloads/tree/main/cis-oke). It deploys Flannel-based basic OKE cluster and one node pool with the characteristics described below. 

This example provides no cluster access automation. Automating access to the cluster can be implemented with the [OCI Bastion service module](https://github.com/oracle-quickstart/terraform-oci-cis-landing-zone-security/tree/main/bastion). See the [available examples](https://github.com/oracle-quickstart/terraform-oci-cis-landing-zone-security/tree/main/bastion/examples).

As alternatives to this example, the following examples are available with cluster access automation:
   1. [OKE Flannel with Access from Localhost](../basic-access-from-localhost/), where the OKE cluster is managed from a host external to OCI (like the user laptop). 
   2. [OKE Flannel with Access from Operator Host](../basic-access-from-operator-host/), where the OKE cluster is managed from a Compute instance deployed in OCI. 

### Pre-Requisite

The OKE cluster and the node pool depend on a pre existing Virtual Cloud Network (VCN). A VCN built specifically for this deployment is available in [flannel network example](https://github.com/oracle-quickstart/terraform-oci-cis-landing-zone-networking/tree/main/examples/oke-examples/flannel).

### Resources Deployed by this Example

OKE cluster (OKE1):
- of *basic* type;
- set with the latest Kubernetes version;
- with Flannel CNI;
- with a private API endpoint.

Node pool (NODEPOOL1):
- created in the same compartment as the cluster;
- with the same Kubernetes version as the cluster;
- with one worker node (it is set by *workers_configuration.node_pools.NODEPOOL1.size* attribute);
- node has the "VM.Standard.E4.Flex" shape;
- node has 16 GB memory and 1 OCPU by default;
- node boot volume size is 60GB and is terminated when the node is destroyed;

See [input.auto.tfvars.template](./input.auto.tfvars.template) for the variables configuration.

## Using this Example
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

Managing Kubernetes applications in OCI includes the ability to invoke OKE API endpoint and SSH'ing into worker nodes. 
As the endpoint and worker nodes are in private subnets, access can be enabled through the OCI Bastion service or via a jump host that is deployed in a public subnet. 

### Access via OCI Bastion Service
- **OKE API endpoint**: Cluster access is enabled by configuring a *kubeconfig* file and setting up the OCI Bastion service endpoint with a Port Forwarding session. [More information](https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengsettingupbastion.htm). 
- **Worker nodes**: SSH access to worker nodes (\*) is enabled by setting up OCI Bastion service endpoint with a Managed SSH session. [More information](https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengsettingupbastion.htm).

Utilize the [OCI Bastion service module](https://github.com/oracle-quickstart/terraform-oci-cis-landing-zone-security/tree/main/bastion) to automate OCI Bastion service provisioning.

(\*) SSH access to worker nodes via the OCI Bastion service requires the Cloud Agent Bastion plugin enabled in the worker nodes.