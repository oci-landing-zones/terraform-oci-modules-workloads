# OKE Flannel with Operator Access Example

## Introduction

This example shows how to deploy OKE clusters and node pools in OCI using the [cis-oke module](https://github.com/oracle-quickstart/terraform-oci-secure-workloads/tree/main/cis-oke). It deploys one Flannel-based basic OKE Cluster, one node pool, one Bastion service endpoint, one Bastion session, and one Compute instance with the characteristics described below. 

Once the cluster is provisioned, cluster access is automatically enabled from the provisioned Compute instance, which is accessible via the OCI Bastion service endpoint. We refer to this Compute instance as the OKE operator host.

### Pre-Requisites

#### Networking
The OKE cluster and the node pool depend on a pre existing Virtual Cloud Network (VCN). A VCN built specifically for this deployment is available in [flannel network example](https://github.com/oracle-quickstart/terraform-oci-cis-landing-zone-networking/tree/main/examples/oke-examples/flannel).

Additionally, the operator host requires an instance principal credential properly authorized for managing the OKE cluster. That means a dynamic group and a policy are required.

#### IAM Dynamic Group and Policy
##### Dynamic Group Matching Rule
```
instance.compartment.id='<COMPUTE-INSTANCE-COMPARTMENT-OCID>'
```

##### Dynamic Group Policy
```
Allow dynamic-group <DYNAMIC-GROUP-NAME> to use cluster-family in compartment <CLUSTER-COMPARTMENT-NAME>
```

Both resources are automated by the [OKE Operator Host IAM example](../oke-operator-host-iam/).


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

Compute instance (INSTANCE-1), a.k.a. operator host:
- based on "VM.Standard.E4.Flex" shape, as defined by the *shape* attribute.
- based on the "Oracle-Linux-Cloud-Developer-8.7-2023.04.28-1" platform image, as defined by *image.id* attribute. Use the [platform-images module](https://github.com/oracle-quickstart/terraform-oci-secure-workloads/tree/main/platform-images) to find Platform images information based on a search filter.
- it does **not** have the boot volume preserved on termination, as defined by *boot_volume.preserve_on_instance_deletion* attribute.
- the boot volume is set to be backed up per Oracle-managed *bronze* backup policy (enforced by the module by default).
- the instance enables the Cloud Agent Bastion plugin, enabling it to accept SSH connections from OCI Bastion service.

Bastion Service endpoint (BASTION-1):
- created in the same subnet as the Compute Instance.

Bastion session (SESSION-1):
- of **MANAGED_SSH** type, allowing SSH connectivity to the operator host.

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
Invoking the OKE API endpoint and accessing Worker nodes differs depending on whether they are in a private or public subnet. This example assumes the API endpoint and worker nodes are in private subnets and are invoked/accessed via an OCI Bastion Service endpoint that is deployed in the *access* subnet, which is also private. This Compute instance (operator host) is accessed via an OCI Bastion service endpoint also deployed in the *access* subnet.

The code automatically connects to the operator host using the Bastion service session to configure the *kubeconfig* file, install *kubectl* tool and set the instance with instance principal authentication.

For connecting to the operator host, execute the command provided in the **sessions** output, that would look like:
```
ssh -i ~/.ssh/id_rsa -o ProxyCommand='ssh -i ~/.ssh/id_rsa -W %h:%p -p 22 ocid1.bastionsession...@host.bastion.eu-frankfurt-1.oci.oraclecloud.com' -p 22 opc@10.0.x.x
```

### Accessing OKE API Endpoint

One connected to the operator Compute instance, use *kubectl* tool to manage your OKE applications. As an example, you can try deploying a sample application, checking and deleting it: 
```
> kubectl create -f https://k8s.io/examples/application/deployment.yaml
> kubectl get deployments
> kubectl delete -f https://k8s.io/examples/application/deployment.yaml
```

### SSH'ing to Worker Nodes

Once connected to the operator host, use *ssh* to connect to any of the worker nodes.