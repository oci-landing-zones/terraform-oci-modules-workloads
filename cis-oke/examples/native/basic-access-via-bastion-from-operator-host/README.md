# OKE NPN (Native Pod Networking) with Operator Access Example

## Introduction

This example shows how to deploy OKE clusters and node pools in OCI using the [cis-oke module](https://github.com/oracle-quickstart/terraform-oci-secure-workloads/tree/main/cis-oke). It deploys one NPN basic OKE Cluster, one node pool, one Bastion service endpoint, one Bastion session, and one Compute instance with the characteristics described below. 

Once the cluster is provisioned, cluster access is automatically enabled from the provisioned Compute instance, which is accessible via the OCI Bastion service endpoint. We refer to this Compute instance as the OKE operator host.

### Pre-Requisites

#### Networking
The OKE cluster and the node pool depend on a pre existing Virtual Cloud Network (VCN). A VCN built specifically for this deployment is available in [native network example](https://github.com/oracle-quickstart/terraform-oci-cis-landing-zone-networking/tree/main/examples/oke-examples/native).

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
- The nodes will have 16 GB memory and 1 ocpu by default.
- The nodes boot volume size will be 60GB and will be terminated when the nodes are destroyed by default.
- The nodes will be placed as following: node1 in ad1 and fd1, node2 in ad1 and fd2 and lastly node3 will be placed in ad1 and fd3 by default.

Commented Virtual Node Pool (VIRTUAL_POOL1):
- The virtual node pool will be created in OKE1 Cluster.
- It will be created in the same compartment as the OKE1 Cluster.
- It will have three virtual worker nodes.
- The pods will use the "Pod.Standard.E4.Flex" shape as defined by the *pod_shape* attribute.

Compute Instance (INSTANCE-1):
- The instance is based on "VM.Standard.E4.Flex" shape, as defined by the *shape* attribute.
- The instance is based on the "Oracle-Linux-Cloud-Developer-8.7-2023.04.28-1" platform image, as defined by *image.id* attribute. Use the [platform-images module](../../../../platform-images/) to find Platform images information based on a search filter.
- The instance will **not** have the boot volume preserved on termination, as defined by *boot_volume.preserve_on_instance_deletion* attribute.
- The instance boot volume is set to be backed up per Oracle-managed *bronze* backup policy (enforced by the module by default).
- The instance has a few Cloud Agent plugins enabled, as defined by *cloud_agent.plugins* attribute. Particularly important to this use case is the Bastion plugin, that enables the instance to accept SSH connections from OCI Bastion service.

Bastion Service (BASTION-1):
- The Bastion should be in the same subnet as the Compute Instance.

Bastion Session (SESSION-1):
- It will be created under BASTION-1 Bastion Service.
- It has the **MANAGED_SSH** type to allow ssh connection to the operator instance.

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