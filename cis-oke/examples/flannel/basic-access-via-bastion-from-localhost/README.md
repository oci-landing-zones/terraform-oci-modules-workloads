# OKE Flannel with Localhost Access Example

## Introduction

This example shows how to deploy OKE clusters and node pools in OCI using the [cis-oke module](https://github.com/oracle-quickstart/terraform-oci-secure-workloads/tree/main/cis-oke). It deploys one Flannel-based basic OKE Cluster, one node pool, one Bastion service endpoint and one Bastion session for application management with the characteristics described below. 

Once the cluster is provisioned, cluster access is automatically enabled from localhost via the OCI Bastion service endpoint.

### Pre-Requisite

The OKE cluster and the Node Pool depend on a pre existing Virtual Cloud Network (VCN). A VCN built specifically for this deployment is available in [flannel network example](https://github.com/oracle-quickstart/terraform-oci-cis-landing-zone-networking/tree/main/examples/oke-examples/flannel).

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
- node boot volume size is 60GB and is terminated when the node is destroyed.

Bastion service (BASTION-1):
- of *standard* type.

Bastion session (SESSION-1):
- of **PORT_FORWARDING** type, allowing port forwarding to the OKE API endpoint;
- targeting the OKE1 cluster API endpoint on port 6443.

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