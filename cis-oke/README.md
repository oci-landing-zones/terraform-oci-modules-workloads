# OCI Landing Zones OKE Module

![Landing Zone logo](../landing_zone_300.png)

This module manages Container Engine For Kubernetes (OKE) clusters, node pools and virtual node pools in Oracle Cloud Infrastructure (OCI). OKE is a fully-managed, scalable, and highly available service that you can use to deploy your containerized applications to the cloud. 

The module supports bringing in external dependencies that managed resources depend on, including compartments, subnets, network security groups, encryption keys, and others. 

Check [module specification](./SPEC.md) for a full description of module requirements, supported variables, managed resources and outputs.

Check the [examples](./examples/) folder for actual module usage.

- [Features](#features)
- [Requirements](#requirements)
- [How to Invoke the Module](#invoke)
- [Module Functioning](#functioning)
  - [OKE Clusters](#oke)
  - [Node Pools](#node-pools)
  - [Virtual Node Pools](#virtual-node-pools)
  - [External Dependencies](#ext-dep) 
- [Related Documentation](#related)
- [Known Issues](#issues)

## <a name="features">Features</a>
The following features are currently supported by the module:

- Basic and Enhanced clusters;
- Standard node pools and virtual node pools;
- Kubernetes secrets encryption with customer managed keys enforced, driven by CIS profile level "2".
- Worker nodes image signing enforced, driven by CIS profile level "2".
- Boot volumes encryption at rest enforced, driven by CIS profile level "2".
- Boot volumes in-transit encryption enforced, drive by CIS profile level "2".

## <a name="requirements">Requirements</a>
### Terraform Version >= 1.3.0

This module requires Terraform binary version 1.3.0 or greater, as it relies on Optional Object Type Attributes feature. The feature shortens the amount of input values in complex object types, by having Terraform automatically inserting a default value for any missing optional attributes.

### IAM Permissions

This module requires the following IAM permissions: 

For deploying OKE Clusters:
```
Allow group <GROUP-NAME> to manage cluster-family in compartment <OKE-CLUSTER-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to manage instance-family in compartment <OKE-CLUSTER-COMPARTMENT-NAME> 
Allow group <GROUP-NAME> to use vnics in compartment <OKE-CLUSTER-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to inspect compartments in compartment <OKE-CLUSTER-COMPARTMENT-NAME> 
Allow group <GROUP-NAME> to read virtual-network-family in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to use subnets in compartment <NETWORK-COMPARTMENT-NAME> 
Allow group <GROUP-NAME> to use network-security-groups in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to use vnics in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to manage private-ips in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to manage public-ips in compartment <NETWORK-COMPARTMENT-NAME> 
```

For allowing load balancers deployments by OKE clusters:
```
Allow any-user to use private-ips in compartment <NETWORK-COMPARTMENT-NAME> where all { request.principal.type = 'cluster', request.principal.compartment.id = '<OKE-CLUSTER-COMPARTMENT-OCID>' }
Allow any-user to use network-security-groups in compartment <NETWORK-COMPARTMENT-NAME> where all { request.principal.type = 'cluster', request.principal.compartment.id = '<OKE-CLUSTER-COMPARTMENT-OCID>' }
Allow any-user to use subnets in compartment <NETWORK-COMPARTMENT-NAME> where all { request.principal.type = 'cluster', request.principal.compartment.id = '<OKE-CLUSTER-COMPARTMENT-OCID>' }
```

For cluster auto-scaling:
```
Allow any-user to manage instances in compartment <OKE-CLUSTER-COMPARTMENT-NAME> where all { request.principal.type = 'cluster', request.principal.compartment.id = '<OKE-CLUSTER-COMPARTMENT-OCID>' }
```

For more information about OKE Policies [click here](https://docs.oracle.com/en-us/iaas/Content/ContEng/Concepts/contengpolicyconfig.htm#Policy_Configuration_for_Cluster_Creation_and_Deployment).

## <a name="invoke">How to Invoke the Module</a>

Terraform modules can be invoked locally or remotely. 

For invoking the module locally, just set the module *source* attribute to the module file path (relative path works). The following example assumes the module is two folders up in the file system.
```
module "oke" {
  source = "../.."
  clusters_configuration = var.clusters_configuration
  workers_configuration  = var.workers_configuration
}
```
For invoking the module remotely, set the module *source* attribute to the *cis-oke* module folder in this repository, as shown:
```
module "oke" {
  source = "github.com/oracle-quickstart/terraform-oci-secure-workloads/cis-oke"
  clusters_configuration = var.clusters_configuration
  workers_configuration  = var.workers_configuration
}
```
For referring to a specific module version, add an extra slash before the folder name and append *ref=\<version\>* to the *source* attribute value, as in:
```
  source = "github.com/oracle-quickstart/terraform-oci-secure-workloads//cis-oke?ref=v0.1.0"
```

## <a name="functioning">Module Functioning</a>

The module defines two top level variables used to manage OKE clusters and node pools: 
- **clusters_configuration**: for managing OKE clusters.
- **workers_configuration**: for managing node pools and virtual node pools.

### <a name="oke">OKE Clusters</a>

OKE Clusters are managed using the **clusters_configuration** object. It contains a set of attributes starting with the prefix **default_** and one attribute named **clusters**. The **default_** attribute values are applied to all clusters within **clusters**, unless overridden at the cluster level.

The *default_* attributes are the following:
- **default_compartment_id**: Default compartment for all clusters. It can be overridden by *compartment_id* attribute in each cluster. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **default_img_kms_key_id**: (Optional) Default image signing key for all clusters. It can be overridden by *img_kms_key_id* attribute in each cluster. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *kms_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **default_kube_secret_kms_key_id**: (Optional) Default kube secret encryption key for all clusters. It can be overridden by *kube_secret_kms_key_id* attribute in each cluster. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *kms_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **default_cis_level**: (Optional) Default CIS OCI Benchmark profile level for all clusters. Level "2" enforces usage of customer managed keys for image signing and kube secrets encryption. Default is "1". It can be overridden by *cis_level* attribute in each cluster.
- **default_defined_tags**: (Optional) Default defined tags for all clusters. It can be overridden by *defined_tags* attribute in each cluster.
- **default_freeform_tags**: (Optional) Default freeform tags for all clusters. It can be overridden by *freeform_tags* attribute in each cluster.

The clusters themselves are defined within the **clusters** attribute. In Terraform terms, it is a map of objects, where each object is referred by an identifying key. The supported attributes are listed below. For better usability, most attributes are grouped in logical blocks. They are properly indented in the list.
- **compartment_id**: (Optional) The cluster compartment. *default_compartment_id* is used if undefined. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **cis_level**: (Optional) The CIS OCI Benchmark profile level to apply. *default_cis_level* is used if undefined.
- **kubernetes_version**: (Optional) the kubernetes version. If not specified, the latest version is selected.
- **name**: the cluster display name.
- **is_enhanced**:(Optional) If the cluster is enhanced. It is designed to work only with native CNI. Default is basic.
- **cni_type**: (Optional) The CNI type of the cluster. It can be either flannel or native. Default is flannel.
- **defined_tags**: (Optional) Clusters defined_tags. *default_defined_tags* is used if undefined.
- **freeform_tags**: (Optional) Clusters freeform_tags. *default_freeform_tags* is used if undefined.
- **options**: (Optional) Options attributes for the cluster.
  - **add_ons**: (Optional) Configurable cluster addons.
    - **dashboard_enabled**: (Optional) Whether Kubernetes dashboard is enabled. Default is false.
    - **tiller_enabled**: (Optional) Whether Tiller is enabled. Default is false.  
  - **admission_controller**: (Optional) Configurable cluster admission controllers. 
    - **pod_policy_enabled**: (Optional) Whether the pod policy is enabled. Default is false.   
  - **kubernetes_network_config**: (Optional) Pods and services network configuration for kubernetes.
    - **pods_cidr**: (Optional) The CIDR block for Kubernetes pods. Optional, defaults to *10.244.0.0/16*.
    - **services_cidr**: (Optional) The CIDR block for Kubernetes services. Optional, defaults to *10.96.0.0/16*. 
  - **persistent_volume_config**: (Optional) Configuration to be applied to block volumes created by Kubernetes Persistent Volume Claims (PVC).
    - **defined_tags**: (Optional) PVC defined_tags. *default_defined_tags* is used if undefined.
    - **freeform_tags**: (Optional) PVC freeform_tags. *default_freeform_tags* is used if undefined. 
  - **service_lb_config**: (Optional) Configuration to be applied to load balancers created by Kubernetes services.
    - **defined_tags**: (Ooptional) Load balancer defined_tags. *default_defined_tags* is used if undefined.
    - **freeform_tags**: (Optional) Load balancer freeform_tags. *default_freeform_tags* is used if undefined.         
- **networking**: (Optional) Cluster networking settings.
  - **vcn_id**:  The vcn where the cluster is created. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *network_dependency* variable. See [External Dependencies](#ext-dep) for details.
  - **is_api_endpoint_public**: (Optional) Whether the OKE API endpoint is public. Default is false.
  - **api_endpoint_nsg_ids**: (Optional) The NSGss used by the OKE API endpoint. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *network_dependency* variable. See [External Dependencies](#ext-dep) for details.
  - **api_endpoint_subnet_id**:  The subnet for the OKE API endpoint. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *network_dependency* variable. See [External Dependencies](#ext-dep) for details.
  - **services_subnet_id**: (Optional) The subnet for the cluster service. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *network_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **encryption**: (Optional) Encryption settings.
  - **kube_secret_kms_key_id**: (Optional) The KMS key to assign as the master encryption key for kube secrets. *default_kube_secret_kms_key_id* is used if undefined. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *kms_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **image_signing**: (Optional) image signing encryption settings
  - **image_policy_enabled**: (Optional) whether the image verification policy is enabled. Default is false.
  - **img_kms_key_id**: (Optional) the KMS key to assign as the *signing* key for images. *default_img_kms_key_id* is used if this is not defined. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *kms_dependency* variable. See [External Dependencies](#ext-dep) for details.

### <a name="Workers">Workers</a>
Workers are managed using the **workers_configuration** object.  It contains a set of attributes starting with the prefix **default_** and two attributes named **node_pools** and **virtual_node_pools**. The **default_** attribute values are applied to all node pools and some of them to all virtual node pools.
The defined **default_** attributes are the following:

- **default_compartment_id**: (Optional) The default compartment for all node pools and virtual node pools. It can be overridden by *compartment_id* attribute in each node pool or virtual pool. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **default_kms_key_id**: (Optional) The default encryption key for nodes in node pools. It can be overridden by *kms_key_id* attribute in each unit. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *kms_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **default_cis_level**: (Optional) The default CIS OCI Benchmark profile level for all node pools. Level "2" enforces usage of customer managed keys for encryption. Default is "1". It can be overridden by *cis_level* attribute in each unit.
- **default_defined_tags**: (Optional) The default defined tags for all node pools and virtual node pools. It can be overridden by *defined_tags* attribute in each unit.
- **default_freeform_tags**: (Optional) the default freeform tags for all node pools and virtual node pools. It can be overridden by *freeform_tags* attribute in each unit.
- **default_ssh_public_key_path**: (Optional) The default SSH public key path used to access all nodes. It can be overridden by the *ssh_public_key* attribute in each node pool.
- **default_initial_node_labels**: (Optional) The default initial node labels for all node pools and virtual node pools, a list of key/value pairs to add to nodes after they join the OKE cluster.

#### <a name="node-pools">Node Pools</a>
Node Pools are defined using the optional **node_pools** attribute. In Terraform terms, it is a map of objects, where each object is referred by an identifying key. The following attributes are supported:
- **cis_level**: (Optional) The CIS OCI Benchmark profile level to apply. The *default_cis_level* is used if undefined.
- **kubernetes_version**: (Optional) The Kubernetes version for the node pool. it cannot be two versions older or newer than the cluster version. If not specified, the version of the cluster is selected.
- **cluster_id**: The cluster where the node pool is created. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to a cluster from the **clusters_configuration**.
- **compartment_id**: (Optional) The compartment where the node pool is created. If the cluster and the node pools are both managed by this module, attributes **compartment_id** and **default_compartment_id** are ignored, as the compartment for the node pool is taken from the cluster assigned to the node pool in the *cluster_id* attribute. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **name**: The node pool display name.
- **defined_tags**: (Optional) The node pool defined_tags. *default_defined_tags* is used if undefined.
- **freeform_tags**: (Optional) The node pool freeform_tags. *default_freeform_tags* is used if undefined.
- **initial_node_labels**: (Optional) A list of key/value pairs to add to nodes after they join the OKE cluster.
- **size**: (Optional) The number of nodes in the node pool.
- **networking**: Node pool networking settings.
  - **workers_nsg_ids**: (Optional) The NSGs where nodes are placed in. This attribute is overloaded. It can be assigned either literal OCIDs or references (keys) to an OCID in *network_dependency* variable. See [External Dependencies](#ext-dep) for details.
  - **workers_subnet_id**: The nodes subnet. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *network_dependency* variable. See [External Dependencies](#ext-dep) for details.
  - **pods_subnet_id**: (Optional) The pods subnet. **Applicable to native CNI only**. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *network_dependency* variable. See [External Dependencies](#ext-dep) for details.
  - **pods_nsg_ids**: (Optional) The NSGs where pods are placed in. **Applicable to native CNI only**. This attribute is overloaded. It can be assigned either literal OCIDs or references (keys) to an OCID in *network_dependency* variable. See [External Dependencies](#ext-dep) for details.
  - **max_pods_per_node**: (Optional) The maximum number of pods per node. **Applicable to native CNI only**.

- **node_config_details**: The configuration of nodes in the node pool.
  - **ssh_public_key_path**: (Optional) The SSH public key path used to access the workers. *default_ssh_public_key_path* is used if undefined.
  - **defined_tags**: (Optional) The nodes defined_tags. *default_defined_tags* is used if undefined.
  - **freeform_tags**: (Optional) The nodes freeform_tags. *default_freeform_tags* is used if undefined.
  - **image**: (Optional) The nodes image. It can be specified as an OCID or as an Oracle Linux Version. Example: "8.8". If not specified the latest Oracle Linux image is selected.
  - **node_shape**: The shape of the nodes.
  - **capacity_reservation_id**: (Optional) The OCID of the compute capacity reservation in which to place the nodes.
  - **flex_shape_settings**: (Optional) Flex shape settings.
    - **memory**: (Optional) The amount of memory for Flex shapes. Default is 16GB.
    - **ocpus**: (Optional) The number of OCPUs for Flex shapes. Default is 1.
  - **boot_volume**: (Optional) The boot volume settings.
    - **size**: (Optional) The boot volume size. Default is 60.
    - **preserve_boot_volume**: (Optional) Whether to preserve the boot volume when nodes are terminated.
  - **encryption**: (Optional) The encryption settings.
    - **enable_encrypt_in_transit**: (Optional) Whether to enable in-transit encryption. Default is false.
    - **kms_key_id**: (Optional) The KMS key to assign as the master encryption key. *default_kms_key_id* is used if undefined.
  - **placement**: (Optional) Placement settings.
    - **availability_domain**: (Optional) The nodes availability domain. Default is 1.
    - **fault_domain**: (Optional) The nodes fault domain. Default is 1.
  - **node_eviction**: (Optional) Nodes eviction settings.
    - **grace_duration**: (Optional) The duration in seconds after which OKE gives up on pods eviction on the node. Default is 3600 seconds.
    - **force_delete**: (Optional) Whether the nodes should be deleted if all pods are not evicted during the grace period.
  - **node_cycling**: (Optional) Nodes cycling settings. **Applicable to enhanced clusters only**.
    - **enable_cycling**: (Optional) Whether node cycling is enabled. Default is false.
    - **max_surge**: (Optional) The maximum number of additional new compute instances that are temporarily created and added to node pool during the cycling process. OKE supports both integer and percentage input. Default is 1. It ranges from 0 up to node pool size or between 0% to 100%.
    - **max_unavailable**: (Optional) The maximum number of active nodes that are terminated from node pool during the cycling process. OKE supports both integer and percentage input. Default is 0. It ranges from 0 up to node pool size or between 0% to 100%.

#### <a name="virtual-node-pools">Virtual Node Pools</a>
Virtual Node Pools are defined using the optional **virtual_node_pools** attribute. In Terraform terms, it is a map of objects, where each object is referred by an identifying key. The following attributes are supported:
- **cluster_id**: The cluster where the virtual node pool is created. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to a cluster from the **clusters_configuration**.
- **compartment_id**: (Optional) The compartment where the virtual node pool is created. If the cluster and the virtual node pools are both managed by this module, the attributes **compartment_id** and **default_compartment_id** are ignored, as the compartment for the virtual node pool is taken from the cluster assigned to the virtual node pool in the **cluster_id** attribute. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **name**: The virtual node pool display name.
- **defined_tags**: (Optional) The virtual node pool defined_tags. *default_defined_tags* is used if undefined.
- **freeform_tags**: (Optional) The virtual node pool freeform_tags. *default_freeform_tags* is used if undefined.
- **virtual_nodes_defined_tags**: (Optional) The defined_tags that apply to virtual nodes. *default_defined_tags* is used if undefined.
- **virtual_nodes_freeform_tags**: (Optional) The freeform_tags that apply to virtual nodes. *default_freeform_tags* is used if undefined.
- **initial_node_labels**: (Optional) A list of key/value pairs to add to virtual nodes when they join the OKE cluster.
- **size**: (Optional) The number of nodes in the virtual node pool.
- **pod_shape**: The pods shape. At the time this Terraform code was created, the shapes available are: "Pod.Standard.A1.Flex", "Pod.Standard.E3.Flex", "Pod.Standard.E4.Flex". 
- **networking**: The virtual node pool networking settings.
  - **workers_nsg_ids**: (Optional) The NSGs where the virtual nodes are placed. This attribute is overloaded. It can be assigned either literal OCIDs or references (keys) to an OCID in *network_dependency* variable. See [External Dependencies](#ext-dep) for details.
  - **workers_subnet_id**: The virtual nodes subnet. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *network_dependency* variable. See [External Dependencies](#ext-dep) for details.
  - **pods_subnet_id**: (Optional) the pods subnet. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *network_dependency* variable. See [External Dependencies](#ext-dep) for details.
  - **pods_nsg_ids**: (Optional) The NSGs where the pods are placed. This attribute is overloaded. It can be assigned either literal OCIDs or references (keys) to an OCID in *network_dependency* variable. See [External Dependencies](#ext-dep) for details.
  - **placement**: (Optional) The placement settings.
    - **availability_domain**: (Optional) The virtual nodes availability domain. Default is 1.
    - **fault_domain**: (Optional) The virtual nodes fault domain. Default is 1.
  - **taints**: (Optional) Taints enable virtual nodes to repel pods, thereby ensuring that pods do not run on virtual nodes in a particular virtual node pool. Taints work together with Kubernetes tolerations to ensure that pods are not scheduled in undesired nodes.
    - **effect**: (Optional) The taint effect. Valid values are "NoSchedule", "NoExecute", or "PreferNoSchedule".
    - **key**: (Optional) The node label key to apply the taint to.
    - **value**: (Optional) The node label value to apply the taint to.


### <a name="ext-dep">External Dependencies</a>
An optional feature, external dependencies are resources managed elsewhere that resources managed by this module may depend on. The following dependencies are supported:
- **compartments_dependency**: A map of objects containing the externally managed compartments this module may depend on. All map objects must have the same type and must contain at least an *id* attribute with the compartment OCID.

Example:
```
{
	"APP-CMP": {
		"id": "ocid1.compartment.oc1..aaaaaaaa...7xq"
	}
}
```
- **network_dependency**: A map of objects containing the externally managed network resources (including subnets and network security groups) this module may depend on. All map objects must have the same type and should contain the following attributes:
  - An *id* attribute with the VCN OCID.
  - An *id* attribute with the subnet OCID.
  - An *id* attribute with the network security group OCID.

Example:
```
{
  "vcns" : {
    "OKE-VCN" : {
      "id" : "ocid1.vcn.oc1.iad.aaaaaaaax...t6h"
    }
  },
  "subnets" : {
    "APP-SUBNET" : {
      "id" : "ocid1.subnet.oc1.iad.aaaaaaaax...e7a"
    }
  },
  "network_security_groups" : {  
    "APP-NSG" : {
      "id" : "ocid1.networksecuritygroup.oc1.iad.aaaaaaaa...xlq"
    }
  }  
} 
```  
- **kms_dependency**: A map of objects containing the externally managed encryption keys this module may depend on. All map objects must have the same type and must contain at least an *id* attribute with the encryption key OCID.

Example:
```
{
	"APP-KEY": {
		"id": "ocid1.key.oc1.iad.ejsppeqvaafyi.abuwcl...yna"
	}
}
```

## <a name="related">Related Documentation</a>
- [OKE](https://docs.oracle.com/en-us/iaas/Content/ContEng/Concepts/contengoverview.htm)


## <a name="issues">Known Issues</a>

### Node pool
1. When updating the *node_cycling* attribute, if you are changing anything else to node_config_details, you will get the following error:

```
 Error: 409-Conflict, Cannot perform nodepool cycling and nodepool Placement Configuration change simultaneously.
│ Suggestion: The resource is in a conflicted state. Please retry again or contact support for help with service: Containerengine Node Pool
│ Documentation: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/containerengine_node_pool
│ API Reference: https://docs.oracle.com/iaas/api/#/en/containerengine/20180222/NodePool/UpdateNodePool
│ Request Target: PUT https://containerengine.eu-frankfurt-1.oci.oraclecloud.com/20180222/nodePools/ocid1.nodepool.oc1.eu-frankfurt-1.aaaaaaaa5gyeinkioj74eobjxv5rryn24bwkxp2k4zx6ks53nnx6l53eazza
│ Provider version: 5.16.0, released on 2023-10-11. This provider is 10 Update(s) behind to current.
│ Service: Containerengine Node Pool
│ Operation Name: UpdateNodePool
│ OPC request ID: 59bbfd0704eff01d226851aa8adba0b2/D3D0C22D125AAB7680601414509B46D8/71438074CF7D178285DD4AE5A9E82632
│
│
│   with module.oke.oci_containerengine_node_pool.these["pool1"],
│   on ../../nodepool.tf line 30, in resource "oci_containerengine_node_pool" "these":
│   30: resource "oci_containerengine_node_pool" "these" 
```

2. When the *image* attribute is not specified, the most recent available image is selected. This means OKE selects the most recent image at every run, hence modifying the node pool. However, the new image is available only for the newly created/recreated nodes in the pool.

### Virtual Pool
Some of the features available for node pools are not supported in virtual node pools. For a detailed list, check the [documentation](https://docs.public.oneportal.content.oci.oraclecloud.com/en-us/iaas/Content/ContEng/Tasks/contengcomparingvirtualwithmanagednodes_topic.htm).
Some examples:
1. Flannel and other third party CNI plugins are not supported. Virtual nodes only supported the OCI VCN-Native Pod Networking CNI plugin.
2. Persistent volume claims (PVCs) are not supported.
4. Network providers that support NetworkPolicy resources alongside the CNI plugin used in the cluster (such as Calico and Cilium) are not supported.