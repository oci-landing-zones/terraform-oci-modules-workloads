# OKE Flannel with Operator Access Example

## Introduction

This example shows how to deploy OKE clusters and node pools in OCI using the [OKE module](../../..). It deploys one Flannel-based basic OKE Cluster, one node pool, one Bastion service endpoint, one Bastion session, and one Compute instance with the characteristics described below. 

Once the cluster is provisioned, cluster access is automatically enabled from the provisioned Compute instance, which is accessible via the OCI Bastion service endpoint. We refer to this Compute instance as the Operator host.

### Pre-Requisites

#### Networking
The OKE cluster and the node pool depend on a pre existing Virtual Cloud Network (VCN). A VCN built specifically for this deployment is available in [flannel network example](https://github.com/oracle-quickstart/terraform-oci-cis-landing-zone-networking/tree/main/examples/oke-examples/flannel).

Additionally, the Operator host requires an instance principal credential properly authorized for managing the OKE cluster. That means a dynamic group and a policy are required.

#### IAM Dynamic Group and Policy
##### Dynamic Group Matching Rule
```
instance.compartment.id='<OPERATOR-HOST-COMPARTMENT-OCID>'
```

##### Dynamic Group Policy
```
Allow dynamic-group <DYNAMIC-GROUP-NAME> to manage cluster-family in compartment <OKE-CLUSTER-COMPARTMENT-NAME>
```

The deployment of these IAM resources are automated by the [OKE Operator Host IAM example](../oke-operator-host-iam/).


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

Compute instance (INSTANCE-1), a.k.a. Operator host:
- based on "VM.Standard.E4.Flex" shape, as defined by the *shape* attribute.
- based on the "Oracle-Linux-Cloud-Developer-8.7-2023.04.28-1" platform image, as defined by *image.id* attribute. 
   - Either use the [platform-images module](https://github.com/oracle-quickstart/terraform-oci-secure-workloads/tree/main/platform-images) to find Platform images information based on a search filter or search for the region-specific image OCID in [All Image Families](https://docs.oracle.com/en-us/iaas/images/).
- it does **not** have the boot volume preserved on termination, as defined by *boot_volume.preserve_on_instance_deletion* attribute.
- the boot volume is set to be backed up per Oracle-managed *bronze* backup policy (enforced by the module by default).
- the instance enables the Cloud Agent Bastion plugin, enabling it to accept SSH connections from OCI Bastion service.

Bastion Service endpoint (BASTION-1):
- created in the same subnet as the Operator host.

Bastion session (SESSION-1):
- of **MANAGED_SSH** type, allowing SSH connectivity to the Operator host.

See [input.auto.tfvars.template](./input.auto.tfvars.template) for the variables configuration.

## Using this Example
1. Rename *input.auto.tfvars.template* to *\<project-name\>.auto.tfvars*, where *\<project-name\>* is any name of your choice.

2. Within *\<project-name\>.auto.tfvars*, provide tenancy connectivity information and adjust the input variables, by making the appropriate substitutions:
   - Replace \<REPLACE-BY-\*\> placeholders with appropriate values. 
   
Refer to [oke module README.md](https://github.com/oracle-quickstart/terraform-oci-secure-workloads/tree/main/oke/README.md) for overall attributes usage.

3. In this folder, run the typical Terraform workflow:
```
terraform init
terraform plan -out plan.out
terraform apply plan.out
```

## Accessing the Cluster

Managing Kubernetes applications in OCI includes the ability to invoke OKE API endpoint and SSH'ing into worker nodes. 
Invoking the OKE API endpoint and accessing worker nodes differs depending on whether they are in a private or public subnet. This example assumes the API endpoint and worker nodes are in private subnets and are invoked/accessed from the Operator host, which is reachable via the OCI Bastion service.

The code automatically connects to the Operator host using the Bastion service session to configure the *kubeconfig* file, install *kubectl* tool and set the instance with instance principal authentication.

For connecting to the Operator host, execute the command provided in the **sessions** output, that would look like:
```
ssh -i <private-key> -o ProxyCommand='ssh -i <private-key> -W %h:%p -p 22 ocid1.bastionsession.XXXXXXXX@host.bastion.<region>oci.oraclecloud.com' -p 22 opc@<operator-host-ip-address>
```

### Accessing OKE API Endpoint

One connected to the Operator host, use *kubectl* tool to manage your OKE applications. As an example, you can try deploying a sample application, checking and deleting it: 
```
> kubectl create -f https://k8s.io/examples/application/deployment.yaml
> kubectl get deployments
> kubectl delete -f https://k8s.io/examples/application/deployment.yaml
```

If for some reason *kubectl* does not get installed, once connected to the host, execute the [install_kubectl.sh](./install_kubectl.sh) script manually.

After installing *kubectl*, if you can't get access to the cluster, confirm there is a *config* file under *$HOME/.kube*. Otherwise, manually create *kubeconfig* file, by executing:
```
oci ce cluster create-kubeconfig --cluster-id <CLUSTER-OCID> --file $HOME/.kube/config --region <REGION-NAME> --token-version 2.0.0  --kube-endpoint PRIVATE_ENDPOINT
```
**Note**: the command above can be obtained in OCI Console, navigating to the "Quick Start" link within the OKE cluster.

### Connecting to Worker Nodes via SSH

This is done from the Operator host:

1. Make the SSH private key that matches the SSH public key in the worker node available in the Operator host. If the private key is available in your local machine, it can be copied to the Operator host like:
```
scp -J ocid1.bastionsession.XXXXXXXX@host.bastion.<region>oci.oraclecloud.com <private-key> opc@<operator-host-ip-address>:<private-key>
```
2. Connect to the Operator host using the SSH command in the **sessions** output:
```
ssh -i <private-key> -o ProxyCommand='ssh -i <private-key> -W %h:%p -p 22 ocid1.bastionsession.XXXXXXXX@host.bastion.<region>oci.oraclecloud.com' -p 22 opc@<operator-host-ip-address>
```
3. Restrict permissions on the private SSH key:
```
chmod 600 <private-key>
``` 
4. Connect to the worker node via SSH:
```
ssh -i <private-key> opc@<worker-node-ip-address>
```

Optionally, you can manually create a managed SSH session for the worker node in the provisioned OCI Bastion service, bypassing the Operator host altogether.

1. Using the Console, enable the Cloud Agent Bastion plugin in the worker node.
2. Using the Console, create a managed SSH session for the worker node in the provisioned OCI Bastion service.
3. Connect to worker node using the SSH command provided for the managed SSH session. The command looks like:
```
ssh -o ProxyCommand="ssh -W %h:%p -p 22 ocid1.bastionsession.XXXXXXXXX@host.bastion.us-phoenix-1.oci.oraclecloud.com" -p 22 opc@<worker-node-ip-address>
```