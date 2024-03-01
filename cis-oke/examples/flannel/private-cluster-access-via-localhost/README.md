# OKE Flannel with Localhost Access Example

## Introduction

This example shows how to deploy OKE clusters and node pools in OCI using the [cis-oke module](https://github.com/oracle-quickstart/terraform-oci-secure-workloads/tree/main/cis-oke). It deploys one Flannel-based OKE Cluster, one node pool, one Bastion service and one Bastion session for application management with the characteristics described below.

### Pre-Requisite

The OKE cluster, the node pool and the Bastion service depend on a pre-existing Virtual Cloud Network (VCN). A VCN built specifically for this deployment is available in [flannel_external network example](https://github.com/oracle-quickstart/terraform-oci-cis-landing-zone-networking/tree/main/examples/oke-examples/flannel_external).

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

Bastion Service (BASTION-1):
- The Bastion type is standard.

Bastion Session (SESSION-1):
- It will be created under BASTION-1 Bastion service.
- It has the **PORT_FORWARDING** type to allow port forwarding to the OKE API endpoint.
- It targets the OKE1 cluster's API endpoint on port 6443.

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

Managing Kubernetes applications in OCI includes the ability to invoke OKE API endpoint and (in some rare cases) SSH'ing into Worker nodes. 
Invoking the OKE API endpoint and accessing Worker nodes differs depending on whether they are in a private or public subnet. This example assumes the API endpoint and Worker nodes are in private subnets and are invoked/accessed via a Bastion Service endpoint that is deployed in the Bastion subnet, which is also private. 

The code automatically creates a Kube config file in the root folder, required for accessing the API endpoint.

To connect to the API endpoint, in a terminal, execute the command provided in the **sessions** output, that would look like:
```
ssh -i ~/.ssh/id_rsa -N -L 6443:10.0.x.x:6443 -p 22 ocid1.bastionsession.oc1...@host.bastion.eu-frankfurt-1.oci.oraclecloud.com
```

Following that, in another terminal, set the KUBECONFIG environment variable to the Kube config file that was created in the root terraform code folder. Example: ```export KUBECONFIG = <full-path-to-kubeconfig>```

You are now all set to use *kubectl* tool to manage your OKE applications. As an example, you can try deploying a sample application, check it and delete it: 
```
> kubectl create -f https://k8s.io/examples/application/deployment.yaml
> kubectl get deployments
> kubectl delete -f https://k8s.io/examples/application/deployment.yaml
```
