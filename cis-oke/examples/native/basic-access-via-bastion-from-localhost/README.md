# OKE NPN (Native Pod Networking) with Localhost Access Example

## Introduction

This example shows how to deploy OKE clusters and node pools in OCI using the [cis-oke module](https://github.com/oracle-quickstart/terraform-oci-secure-workloads/tree/main/cis-oke). It deploys one NPN basic OKE Cluster, one node pool, one Bastion service endpoint and one Bastion session for application management with the characteristics described below. 

### Pre-Requisite

The OKE cluster and the Node Pool depend on a pre existing Virtual Cloud Network (VCN). A VCN built specifically for this deployment is available in [native network example](https://github.com/oracle-quickstart/terraform-oci-cis-landing-zone-networking/tree/main/examples/oke-examples/native).

### Resources Deployed by this Example

OKE Cluster (OKE1):
- The Cluster will be a Basic Cluster by default.
- The Cluster will have the native cni as defined in the *cni_type* attribute.
- The Cluster will have the latest kubernetes version by default.
- The cluster will have a private api endpoint by default.

Node Pool (NODEPOOL1):
- The nodepool will be created in OKE1 Cluster.
- The nodes will be created in the same compartment as the OKE1 Cluster.
- The nodes will have the same kubernetes version as the OKE1 Cluster.
- The nodepool will have three worker nodes.
- The nodes will use the "VM.Standard.E4.Flex" shape as defined by the *node_shape* attribute.
- The nodes will use the latest OKE image available.
- The nodes will have 16 GB memory and 1 OCPU by default.
- The nodes boot volume size will be 60GB and will be terminated when the nodes are destroyed by default.
- The nodes will be placed as following: node1 in ad1 and fd1, node2 in ad1 and fd2 and lastly node3 will be placed in ad1 and fd3 by default.

Commented Virtual Node Pool (VIRTUAL_POOL1):
- The virtual node pool will be created in OKE1 Cluster.
- It will be created in the same compartment as the OKE1 Cluster.
- It will have three virtual worker nodes.
- The pods will use the "Pod.Standard.E4.Flex" shape as defined by the *pod_shape* attribute.

Bastion Service (BASTION-1):
- The Bastion type is standard.

Bastion Session (SESSION-1):
- It will be created under BASTION-1 Bastion Service.
- It has the **PORT_FORWARDING** type to allow port forward to the OKE API Endpoint.
- It targets the api endpoint on OKE1 Cluster on port 6443.

### How to create Virtual Node Pools

To create Virtual Node Pools you need to make the cluster enhanced by setting the attribute **is_enhanced** to **true** and uncomment the **virtual_node_pools** map.
Virtual Node Pools only work on enhanced clusters.

To create **only** Virtual Node Pools, comment/remove the **node_pools** map.

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

## Accessing the Cluster

Managing Kubernetes applications in OCI includes the ability to invoke OKE API endpoint and SSH'ing into Worker nodes. 
Invoking the OKE API endpoint and accessing Worker nodes differs depending on whether they are in a private or public subnet. This example assumes the API endpoint and Worker nodes are in private subnets and are invoked/accessed via an OCI Bastion Service endpoint that is deployed in the Access subnet, which is also private. 

### Accessing OKE API Endpoint

The code automatically creates a *kubeconfig* file in the Terraform configuration folder, required for accessing the OKE API endpoint.

To connect to the OKE API endpoint, in a terminal, execute the command provided in the **sessions** output, that would look like:
```
ssh -i ~/.ssh/id_rsa -N -L 6443:10.0.x.x:6443 -p 22 ocid1.bastionsession.oc1...@host.bastion.eu-frankfurt-1.oci.oraclecloud.com
```

Following that, in another terminal, set the KUBECONFIG environment variable to the *kubeconfig* file that was created in the Terraform configuration folder. Example: ```export KUBECONFIG = <full-path-to-kubeconfig>```

You are now all set to use *kubectl* tool to manage your OKE applications. As an example, you can try deploying a sample application, checking and deleting it: 
```
> kubectl create -f https://k8s.io/examples/application/deployment.yaml
> kubectl get deployments
> kubectl delete -f https://k8s.io/examples/application/deployment.yaml
```

### SSH'ing to Worker Nodes

Create a Bastion session in the provisioned OCI Bastion service for accessing specific worker nodes in the cluster.
