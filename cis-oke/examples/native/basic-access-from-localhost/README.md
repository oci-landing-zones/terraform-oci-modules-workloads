# OCI Landing Zones OKE Module - NPN (Native Pod Networking) with Localhost Access Example

## Introduction

This example shows how to deploy OKE clusters and node pools in OCI using the [OCI Landing Zones OKE module](../../../README.md). It deploys one NPN basic OKE Cluster, one node pool, one Bastion service endpoint and one Bastion session for cluster management with the characteristics described below. 

### Pre-Requisite

The OKE cluster and the node pool depend on a pre existing Virtual Cloud Network (VCN). A VCN built specifically for this deployment is available at [native network example](https://github.com/oracle-quickstart/terraform-oci-cis-landing-zone-networking/tree/main/examples/oke-examples/native).

### Resources Deployed by this Example

OKE Cluster (OKE1):
- of *basic* type.
- set with the latest Kubernetes version;
- with NPN (Native Pod Networking) CNI;
- with a private API endpoint.

Node Pool (NODEPOOL1):
- created in the same compartment as the cluster;
- with the same Kubernetes version as the cluster;
- with one worker node (it is set by *workers_configuration.node_pools.NODEPOOL1.size* attribute);
- node has the "VM.Standard.E4.Flex" shape;
- node has 16 GB memory and 1 OCPU by default;
- node boot volume size is 60GB and is terminated when the node is destroyed.

Commented Virtual Node Pool (VIRTUALPOOL1):
- created in the same compartment as the cluster;
- with one worker node;
- node has the "VM.Standard.E4.Flex" shape;

Bastion Service (BASTION-1):
- of *standard* type.

Bastion Session (SESSION-1):
- of **PORT_FORWARDING** type, allowing port forwarding to the OKE API endpoint;
- targeting the OKE1 cluster API endpoint on port 6443.

### How to Create Virtual Node Pools

For adding a virtual node pool to the cluster, set the attribute *is_enhanced* to *true* and uncomment the *virtual_node_pools* attribute. Virtual node pools only work on enhanced clusters.

For having the cluster with **only** virtual node pools, comment/remove the *node_pools* attribute.

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

Following that, in another terminal, set the KUBECONFIG environment variable to the *kubeconfig* file that was created in the Terraform configuration folder. 
```
export KUBECONFIG = <full-path-to-kubeconfig>
```

You are now all set to use *kubectl* tool to manage your OKE applications. As an example, you can try deploying a sample application, checking and deleting it: 
```
> kubectl create -f https://k8s.io/examples/application/deployment.yaml
> kubectl get deployments
> kubectl delete -f https://k8s.io/examples/application/deployment.yaml
```

### Connecting to Worker Nodes with SSH

1. Using the Console, enable the Cloud Agent Bastion plugin in the worker node.
2. Using the Console, create a managed SSH session for the worker node in the provisioned OCI Bastion service.
3. Connect to worker node using the SSH command provided for the managed SSH session. The command looks like:
```
ssh -o ProxyCommand="ssh -W %h:%p -p 22 ocid1.bastionsession.XXXXXXXXX@host.bastion.us-phoenix-1.oci.oraclecloud.com" -p 22 opc@<worker-node-ip-address>
```
