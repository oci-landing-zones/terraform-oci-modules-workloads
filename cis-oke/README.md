# Oracle Cloud Infrastructure (OCI) Terraform CIS Compute & Storage (Block Volumes and File System Storage) Module

![Landing Zone logo](../landing_zone_300.png)

This module manages Kubernetes Clusters and Node Pools in Oracle Cloud Infrastructure (OCI). These resources and their associated resources can be deployed together in the same configuration or separately. The module enforces Center for Internet Security (CIS) Benchmark recommendations for all supported resource types and provides features for strong cyber resilience posture. Additionally, the module supports bringing in external dependencies that managed resources depend on, including compartments, subnets, network security groups, encryption keys, and others. 

Check [module specification](./SPEC.md) for a full description of module requirements, supported variables, managed resources and outputs.

Check the [examples](./examples/) folder for actual module usage.

- [Features](#features)
- [Requirements](#requirements)
- [Module Functioning](#functioning)
  - [OKE](#oke)
  - [Node Pools](#node-pools)
  - [External Dependencies](#ext-dep)
- [Related Documentation](#related)
- [Known Issues](#issues)

## <a name="features">Features</a>
The following security features are currently supported by the module:


### <a name="oke-features">OKE</a>
- CIS profile level drives data at rest encryption configuration.
- Image encryption with customer managed keys from OCI Vault service.
- Kube secrets encryption with customer managed keys from OCI Vault service.

### <a name="nodes-features">Node Pools</a>
- CIS profile level drives data at rest encryption configuration.
- Boot volumes encryption with customer managed keys from OCI Vault service.
- In-transit encryption for boot volumes and attached block volumes.



## <a name="requirements">Requirements</a>
### IAM Permissions

This module requires the following OCI IAM permissions in the compartments where OKE and Node Pools are defined. 

For deploying Kubernetes Clusters:
```
Allow group <GROUP-NAME> to manage instance-family in compartment <OKE-COMPARTMENT-NAME> 
Allow group <group-name> to use subnets in compartment <OKE-COMPARTMENT-NAME> 
Allow group <group-name> to manage virtual-network-family in compartment <OKE-COMPARTMENT-NAME> 
Allow group <group-name> to inspect compartments in compartment <OKE-COMPARTMENT-NAME> 
Allow group <group-name> to use vnics in compartment <OKE-COMPARTMENT-NAME> 
Allow group <group-name> to use network-security-groups  in compartment <OKE-COMPARTMENT-NAME> 
Allow group <group-name> to use private-ips  in compartment <OKE-COMPARTMENT-NAME> 
Allow group <group-name> to manage public-ips  in compartment <OKE-COMPARTMENT-NAME> 
Allow group <group-name> to manage cluster-family in compartment <OKE-COMPARTMENT-NAME> 
```

For more information about OKE Policies [click here](https://docs.oracle.com/en-us/iaas/Content/ContEng/Concepts/contengpolicyconfig.htm#Policy_Configuration_for_Cluster_Creation_and_Deployment).

### Terraform Version > 1.3.x

This module relies on [Terraform Optional Object Type Attributes feature](https://developer.hashicorp.com/terraform/language/expressions/type-constraints#optional-object-type-attributes), which has been promoted and no longer experimental in versions greater than 1.3.x. The feature shortens the amount of input values in complex object types, by having Terraform automatically inserting a default value for any missing optional attributes.

## <a name="functioning">Module Functioning</a>

The module defines two top level attributes used to manage kubernetes clusters and node pools: 
- **cluster_configuration** &ndash; for managing Kubernetes Clusters.
- **worker_configuration** &ndash; for managing Node pools.

### <a name="oke">OKE</a>

Kubernetes Clusters are managed using the **cluster_configuration** object. It contains a set of attributes starting with the prefix **default_** and one attribute named **oke**. The **default_** attribute values are applied to all clusters within **oke**, unless overriden at the oke level.

The *default_* attributes are the following:
- **default_compartment_id** &ndash; Default compartment for all clusters. It can be overriden by *compartment_id* attribute in each cluster. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **default_img_kms_key_id** &ndash; (Optional) Default image encryption key for all clusters. It can be overriden by *img_kms_key_id* attribute in each cluster. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *kms_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **default_kube_secret_kms_key_id** &ndash; (Optional) Default kube secret encryption key for all clusters. It can be overriden by *kube_secret_kms_key_id* attribute in each cluster. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *kms_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **default_cis_level** &ndash; (Optional) Default CIS OCI Benchmark profile level for all clusters. Level "2" enforces usage of customer managed keys for image and kube secrets encryption. Default is "1". It can be overriden by *cis_level* attribute in each cluster.
- **default_defined_tags** &ndash; (Optional) Default defined tags for all clusters. It can be overriden by *defined_tags* attribute in each cluster.
- **default_freeform_tags** &ndash; (Optional) Default freeform tags for all clusters. It can be overriden by *freeform_tags* attribute in each cluster.

The clusters themselves are defined within the **oke** attribute, In Terraform terms, it is a map of objects. where each object is referred by an identifying key. The supported attributes are listed below. For better usability, most attributes are grouped in logical blocks. They are properly indented in the list.
- **compartment_id** &ndash; (Optional) The cluster compartment. *default_compartment_id* is used if undefined. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **cis_level** &ndash; (Optional) The CIS OCI Benchmark profile level to apply. *default_cis_level* is used if undefined.
- **kubernetes_version** &ndash; (Optional) the kubernetes version. If not specified the latest version will be selected.
- **name** &ndash; the cluster display name.
- **is_enhanced** &ndash;(Optional) If the cluster is enhanced. It is designed to work only on Native CNI. If not specified, basic will be selected.
- **cni_type** &ndash; (Optional) The CNI type of the cluster. Can be either flannel or native. If not specified, native will be selected.
- **defined_tags** &ndash; (Optional) clusters defined_tags. default_defined_tags is used if this is not defined.
- **freeform_tags** &ndash; (Optional) clusters freeform_tags. default_freeform_tags is used if this is not defined.
- **options** &ndash; (Optional) options attributes for the cluster.
  - **add_ons** &ndash; (Optional) configurable cluster addons.
    - **dashboard_enabled** &ndash; (Ooptional) if the dashboard is enabled. Default to false.
    - **tiller_enabled** &ndash; (Optional) if the tiller is enabled. Default to false.  
  - **admission_controller** &ndash; (Optional) configurable cluster admission controllers. 
    - **pod_policy_enabled** &ndash; (Ooptional) if the pod policy is enabled. Default to false.   
  - **kubernetes_network_config** &ndash; (Optional) pods and services network configuration for kubernetes.
    - **pods_cidr** &ndash; (Ooptional) the CIDR block for Kubernetes pods. Optional, defaults to 10.244.0.0/16.
    - **services_cidr** &ndash; (Optional) the CIDR block for Kubernetes services. Optional, defaults to 10.96.0.0/16. 
  - **persistent_volume_config** &ndash; (Optional) configuration to be applied to block volumes created by Kubernetes Persistent Volume Claims (PVC).
    - **defined_tags** &ndash; (Ooptional) PVC defined_tags. default_defined_tags is used if this is not defined.
    - **freeform_tags** &ndash; (Optional) PVC freeform_tags. default_freeform_tags is used if this is not defined. 
  - **service_lb_config** &ndash; (Optional) configuration to be applied to load balancers created by Kubernetes services
    - **defined_tags** &ndash; (Ooptional) LB defined_tags. default_defined_tags is used if this is not defined.
    - **freeform_tags** &ndash; (Optional) LB freeform_tags. default_freeform_tags is used if this is not defined.         
- **networking** &ndash; (Optional) cluster networking settings.
  - **vcn_id** &ndash;  the vcn where the cluster will be created.
  - **public_endpoint** &ndash; (Optional) if the api endpoint is public. default to false.
  - **nsg_ids** &ndash; (Optional) the nsgs used by the api endpoint.
  - **endpoint_subnet_id** &ndash;  the subnet for the api endpoint.
  - **services_subnet_id** &ndash; (Optional) the subnet for the cluster service
- **encryption** &ndash; (Optional) encryption settings
  - **image_policy_enabled** &ndash; (Optional) whether the image verification policy is enabled. default to false.
  - **img_kms_key_id** &ndash; (Optional) the KMS key to assign as the master encryption key for images. default_img_kms_key_id is used if this is not defined.
  - **kube_secret_kms_key_id** &ndash; (Optional) the KMS key to assign as the master encryption key for kube secrets. default_kube_secret_kms_key_id is used if this is not defined.





### <a name="node-pools">Node Pools</a>

Node Pools are managed using the **workers_configuration** object. It contains a set of attributes starting with the prefix **default_** and an attribute named **node_pool** .The **default_** attribute values are applied to all node pools, unless overriden at the storage unit level.
The defined **default_** attributes are the following:

- **default_compartment_id** &ndash; (Optional) The default compartment for all node pools. It can be overriden by *compartment_id* attribute in each node pool. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **default_kms_key_id** &ndash; (Optional) The default encryption key for nodes. It can be overriden by *kms_key_id* attribute in each unit. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *kms_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **default_cis_level** &ndash; (Optional) The default CIS OCI Benchmark profile level for all node pools. Level "2" enforces usage of customer managed keys for encryption. Default is "1". It can be overriden by *cis_level* attribute in each unit.
- **default_defined_tags** &ndash; (Optional) The default defined tags for all node pools. It can be overriden by *defined_tags* attribute in each unit.
- **default_freeform_tags** &ndash; (Optional) the default freeform tags for all node pools. It can be overriden by *freeform_tags* attribute in each unit.
- **default_ssh_public_key_path** &ndash; (Optional) Default SSH public key path used to access all nodes. It can be overriden by the *ssh_public_key* attribute in each node pool.

#### <a name="node-pools">Node Pools</a>
Node Pools are defined using the  **node_pool** attribute. In Terraform terms, it is a map of objects, where each object is referred by an identifying key. The following attributes are supported:
- **compartment_id** &ndash; (Optional) The volume compartment. The *default_compartment_id* is used if undefined. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **cis_level** &ndash; (Optional) The CIS OCI Benchmark profile level to apply. The *default_cis_level* is used if undefined.
- **kubernetes_version** &ndash; (Optional) the kubernetes version for the node pool. it cannot be 2 versions older behind of the cluster version or newer. If not specified, the version of the cluster will be selected.
- **cluster_id** &ndash; the cluster where the node pool will be created.
- **compartment_id** &ndash; (Optional) the compartment where the node pool is created. default_compartment_ocid is used if this is not defined.
- **name** &ndash; the node pool display nam
- **defined_tags** &ndash; (Optional)  node pool defined_tags. default_defined_tags is used if this is not defined.
- **freeform_tags** &ndash; (Optional) node pool freeform_tags. default_freeform_tags is used if this is not defined.
- **initial_node_labels** &ndash; (Optional) a list of key/value pairs to add to nodes after they join the Kubernetes cluster.
- **size** &ndash; (Optional) the number of nodes that should be in the node pool.
- **networking** &ndash; node pool networking settings.
  - **nsg_ids** &ndash; (Optional) the nsgs to be used by the nodes.
  - **worker_subnet_id** &ndash; the subnet for the nodes.
  - **pods_subnet_id** &ndash; (Optional) the subnet for the pods. only applied to native CNI.
  - **pods_nsg_ids** &ndash; (Optional) the nsgs to be used by the pods. only applied to native CNI.
  - **max_pods_per_node** &ndash; (Optional) the maximum number of pods per node. only applied to native CNI.

- **node_config_details** &ndash; the configuration of nodes in the node pool.
  - **ssh_public_key_pat** &ndash; (Optional) the SSH public key path used to access the workers. if not specified default_ssh_public_key_path will be used.
  - **defined_tags** &ndash; (Optional) nodes defined_tags. default_defined_tags is used if this is not defined.
  - **freeform_tags** &ndash; (Optional) nodes freeform_tags. default_freeform_tags is used if this is not defined.
  - **image** &ndash; (Optional) the image for the nodes. Can be specified as ocid or as an Oracle Linux Version. Example: "8.8". If not specified the latest Oracle Linux image will be selected.
  - **node_shape** &ndash; the shape of the nodes.
  - **capacity_reservation_id** &ndash; (Optional) the OCID of the compute capacity reservation in which to place the nodes.
  - **flex_shape_settings** &ndash; (Optional) flex shape settings
    - **memory** &ndash; (Optional) the nodes memory for Flex shapes. Default is 16GB.
    - **ocpus** &ndash; (Optional) the nodes ocpus number for Flex shapes. Default is 1.

  - **boot_volume** &ndash; (Optional) the boot volume settings.
    - **size** &ndash; (Optional) the boot volume size.Default is 60.
    - **preserve_boot_volume** &ndash; (Optional) whether to preserve the boot volume after the nodes are terminated.

  - **encryption** &ndash; (Optional) the encryption settings.
    - **enable_encrypt_in_transit** &ndash; (Optional) whether to enable the encrypt in transit. Default is false.
    - **kms_key_id** &ndash; (Optional) the KMS key to assign as the master encryption key. default_kms_key_id is used if this is not defined.

  - **placement** &ndash; (Optional) placement settings.
    - **availability_domain** &ndash; (Optional) the nodes availability domain. Default is 1.
    - **fault_domain** &ndash; (Optional) the nodes fault domain. Default is 1.

  - **node_eviction** &ndash; (Optional) node eviction settings.
    - **grace_duration** &ndash; (Optional) duration after which OKE will give up eviction of the pods on the node. Can be specified in seconds. Default is 60 minutes.
    - **force_delete** &ndash; (Optional) whether the nodes should be deleted if you cannot evict all the pods in grace period.

  - **node_cycling** &ndash; (Optional) node cycling settings. Available only for Enhanced clusters.
    - **enable_cycling** &ndash; (Optional) whether to enable node cycling. Default is false.
    - **max_surge** &ndash; (Optional) maximum additional new compute instances that would be temporarily created and added to nodepool during the cycling nodepool process. OKE supports both integer and percentage input. Defaults to 1, Ranges from 0 to Nodepool size or 0% to 100%.
    - **max_unavailable** &ndash; (Optional) maximum active nodes that would be terminated from nodepool during the cycling nodepool process. OKE supports both integer and percentage input. Defaults to 0, Ranges from 0 to Nodepool size or 0% to 100%.


### <a name="ext-dep">External Dependencies</a>
An optional feature, external dependencies are resources managed elsewhere that resources managed by this module may depend on. The following dependencies are supported:
- **compartments_dependency** &ndash; A map of objects containing the externally managed compartments this module may depend on. All map objects must have the same type and must contain at least an *id* attribute with the compartment OCID.

Example:
```
{
	"APP-CMP": {
		"id": "ocid1.compartment.oc1..aaaaaaaa...7xq"
	}
}
```
- **network_dependency** &ndash; A map of objects containing the externally managed network resources (including subnets and network security groups) this module may depend on. All map objects must have the same type and should contain the following attributes:
  - An *id* attribute with the subnet OCID.
  - An *id* attribute with the network security group OCID.

Example:
```
{
  "APP-SUBNET" : {
    "id" : "ocid1.subnet.oc1.iad.aaaaaaaax...e7a"
  }, 
  "APP-NSG" : {
    "id" : "ocid1.networksecuritygroup.oc1.iad.aaaaaaaa...xlq"
  }
} 
```  
- **kms_dependency** &ndash; A map of objects containing the externally managed encryption keys this module may depend on. All map objects must have the same type and must contain at least an *id* attribute with the encryption key OCID.

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
1. When updating the node_cycling attribute, if you are changing anything else to node_config_details, you will get the following error.

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

