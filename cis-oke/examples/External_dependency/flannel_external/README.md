# CIS OCI Flannel CNI OKE with Node Pool and Bastion Service access Example 

## Introduction

This example shows how to deploy Kubernetes Clusters and Node Pools in OCI using the [cis-oke module](../../../). It deploys one Flannel CNI OKE Cluster, one Node Pool, one Bastion Service and one Bastion Session for application management with the characteristics described below.

It will automatically create a **kubeconfig** file in the root folder configured to allow port forward to the OKE API Endpoint.

Before accessing the OKE API Endpoint, you have to set the KUBECONFIG export to this file.```Example: export KUBECONFIG =<fulll-path-to-kubeconfig>```

### Pre-Requisite

The OKE cluster, the Node Pool and the Bastion Service depend on a pre existing Virtual Cloud Network (VCN). A VCN built specifically for this deployment is available in  [flannel_external network example](https://orahub.oci.oraclecorp.com/nace-shared-services/terraform-oci-cis-landing-zone-networking/-/tree/main/examples/oke-examples/flannel_external).

### Resources Deployed by this Example

OKE Cluster (OKE1):
- It will have the latest kubernetes version by default.
- It will have the flannel CNI by default.
- It will have a private api endpoint by default.

Node Pool (NODEPOOL1):
- The node pool will be created in OKE Cluster.
- The nodes will be created in the same compartment as the OKE Cluster.
- The nodes will have the same kubernetes version as the OKE Cluster.
- The node pool will have three worker nodes.
- The nodes will use the "VM.Standard.E4.Flex" shape as defined by the *node_shape* attribute.
- The nodes will have 16 GB memory and 1 OCPU by default.
- The nodes boot volume size will be 60GB and will be terminated when the nodes are destroyed by default.
- The nodes will be placed as following: node 1 in availability domain 1 (AD 1) and fault domain 1 (FD 1), node 2 in AD 1 and FD 2, and lastly,node 3 will be placed in AD 1 and FD 3 by default.

Bastion Service (bastion1):
- The Bastion type is standard.

Bastion Session (session1):
- It will be created under bastion1 Bastion Service.
- It has the **PORT_FORWARDING** type to allow port forward to the OKE API Endpoint.
- It targets the api endpoint on OKE1 Cluster on port 6443.

See [input.auto.tfvars.template](./input.auto.tfvars.template) for the variables configuration.

## Using this example
1. Rename *input.auto.tfvars.template* to *\<project-name\>.auto.tfvars*, where *\<project-name\>* is any name of your choice.

2. Within *\<project-name\>.auto.tfvars*, provide tenancy connectivity information and adjust the input variables, by making the appropriate substitutions:
   - Replace \<REPLACE-BY-\*\> placeholders with appropriate values. 
   
Refer to [cis-oke module README.md](../../../README.md) for overall attributes usage.

3. In this folder, run the typical Terraform workflow:
```
terraform init
terraform plan -out plan.out
terraform apply plan.out
```

## Managing Kubernetes Applications

Managing Kubernetes applications in OCI includes the ability to invoke OKE API endpoint and (in some rare cases) SSH'ing into Worker nodes. 
Invoking the OKE API endpoint and accessing Worker nodes differs depending on whether they are in a private or public subnet. This example assumes the API endpoint and Worker nodes are in private subnets, and are invoked/accessed via a Bastion Servoce that is deployed in the Operator subnet, which is also private. 
