# OCI Landing Zones Compute Module

![Landing Zone logo](../landing_zone_300.png)

This module manages Compute instances, Block Volume, File System Storage, Compute Clusters, and Cluster Networks in Oracle Cloud Infrastructure (OCI). These resources and their associated resources can be deployed together in the same configuration or separately. The module enforces Center for Internet Security (CIS) Benchmark recommendations when appropriate and provides features for strong cyber resilience posture, including cross-region replication and storage backups. Additionally, the module supports bringing in external dependencies that managed resources depend on, including compartments, subnets, network security groups, encryption keys, and others. 

Check [module specification](./SPEC.md) for a full description of module requirements, supported variables, managed resources and outputs.

Check the [examples](./examples/) folder for actual module usage.

- [Features](#features)
- [Requirements](#requirements)
- [How to Invoke the Module](#invoke)
- [Module Functioning](#functioning)
  - [Aspects Driven by CIS Profile Levels](#cis-levels)
  - [Compute](#compute-1)
  - [Block Volumes](#block-volumes-1)
  - [File Storage](#file-storage-1)
    - [File Systems](#file-systems)
    - [Mount Targets](#mount-targets)
    - [Snapshot Policies](#snapshot-policies)
  - [Clusters](#clusters-1)  
  - [External Dependencies](#ext-dep)
- [Related Documentation](#related)
- [Known Issues](#issues)

## <a name="features">Features</a>
The following security features are currently supported by the module:

### <a name="compute-features">Compute</a>
- CIS profile level drives data at rest encryption, in-transit encryption, secure boot (Shielded instances) and legacy v1 Metadata service endpoint availability.
- Boot volumes encryption with customer managed keys from OCI Vault service.
- In-transit encryption for boot volumes and attached block volumes.
- Data in-use encryption for platform images ([Confidential computing](https://docs.oracle.com/en-us/iaas/Content/Compute/References/confidential_compute.htm)).
- [Shielded instances](https://docs.oracle.com/en-us/iaas/Content/Compute/References/shielded-instances.htm).
- Boot volumes backup with Oracle managed policies.
- [Cloud Agent Plugins](https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/manage-plugins.htm).
- Secondary VNICs and secondary IP addresses per VNIC. 

### <a name="block-features">Block Volumes</a>
- CIS profile level drives data at rest encryption configuration.
- Data at rest encryption with customer managed keys from OCI Vault service.
- In-transit encryption for attached Compute instances.
- Cross-region replication for strong cyber resilience posture.
- Backups with Oracle managed policies.
- [Shareable block volume attachments](https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/attachingvolumetomultipleinstances.htm).

### <a name="file-features">File Storage</a>
- CIS profile level drives data at rest encryption configuration.
- Data at rest encryption with customer managed keys from OCI Vault service.
- Cross-region replication for strong cyber resilience posture.
- Backups with custom snapshot policies.

### <a name="cluster-features">Clusters</a>
- Deployment of cluster networks and compute clusters.

## <a name="requirements">Requirements</a>
### Terraform Version >= 1.3.0

This module requires Terraform binary version 1.3.0 or greater, as it relies on Optional Object Type Attributes feature. The feature shortens the amount of input values in complex object types, by having Terraform automatically inserting a default value for any missing optional attributes.

### IAM Permissions

This module requires the following OCI IAM permissions in the compartments where instances, block volumes, and file systems are defined. 

For deploying Compute instances:
```
Allow group <GROUP-NAME> to manage instance-family in compartment <INSTANCE-COMPARTMENT-NAME> # covers block volume attachments
Allow group <GROUP-NAME> to manage backup-policy-assignments in compartment <INSTANCE-COMPARTMENT-NAME> # for boot volume policy assignment
Allow group <GROUP-NAME> to use volumes in compartment <INSTANCE-COMPARTMENT-NAME> # for boot volume policy assignment
Allow group <GROUP-NAME> to use backup-policies in compartment <INSTANCE-COMPARTMENT-NAME> # for boot volume policy assignment
Allow group <GROUP-NAME> to read instance-agent-plugins in compartment <INSTANCE-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to read virtual-network-family in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to use subnets in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to use network-security-groups in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to use vnics in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to manage private-ips in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to read keys in compartment <ENCRYPTION-KEYS-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to use key-delegate in compartment <ENCRYPTION-KEYS-COMPARTMENT-NAME>
```
If (custom) images are not in the same compartment as the instances themselves, add this policy statement:

```
Allow group <GROUP-NAME> to read instance-images in compartment <IMAGE-COMPARTMENT-NAME>
```

For deploying Block volumes:
```
Allow group <GROUP-NAME> to manage volume-family in compartment <BLOCK-VOLUME-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to read keys in compartment <ENCRYPTION-KEYS-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to use key-delegate in compartment <ENCRYPTION-KEYS-COMPARTMENT-NAME>
```

For deploying File Storage file systems:
```
Allow group <GROUP-NAME> to manage file-family in compartment <FILE-SYSTEM-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to read virtual-network-family in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to use subnets in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to use network-security-groups in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to use vnics in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to manage private-ips in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to read keys in compartment <ENCRYPTION-KEYS-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to use key-delegate in compartment <ENCRYPTION-KEYS-COMPARTMENT-NAME>
```

## <a name="invoke">How to Invoke the Module</a>

Terraform modules can be invoked locally or remotely. 

For invoking the module locally, just set the module *source* attribute to the module file path (relative path works). The following example assumes the module is two folders up in the file system.
```
module "compute" {
  source = "../.."
  providers = {
    oci = oci
    oci.block_volumes_replication_region = oci.block_volumes_replication_region
  }
  instances_configuration = var.instances_configuration
  storage_configuration   = var.storage_configuration
}
```
For invoking the module remotely, set the module *source* attribute to the *cis-compute-storage* module folder in this repository, as shown:
```
module "compute" {
  source = "github.com/oracle-quickstart/terraform-oci-secure-workloads/cis-compute-storage"
  providers = {
    oci = oci
    oci.block_volumes_replication_region = oci.block_volumes_replication_region
  }
  instances_configuration = var.instances_configuration
  storage_configuration   = var.storage_configuration
}
```
For referring to a specific module version, add an extra slash before the folder name and append *ref=\<version\>* to the *source* attribute value, as in:
```
  source = "github.com/oracle-quickstart/terraform-oci-secure-workloads//cis-compute-storage?ref=v0.1.0"
```

## <a name="functioning">Module Functioning</a>

The module defines two top level variables used to manage instances, storage, clusters and cluster configurations: 
- **instances_configuration** &ndash; for managing Compute instances.
- **storage_configuration** &ndash; for managing storage, including Block Volumes and File System Storage.
- **clusters_configuration** &ndash; for managing clusters, including cluster networks and compute clusters.
- **cluster_instances_configuration** &ndash; for managing instance configurations used in cluster networks.

### <a name="cis-levels">Aspects Driven by CIS Profile Levels</a>

The CIS Benchmark profile levels drive some aspects of Compute and Storage. In this module, the profile levels are defined via the *default_cis_level* attribute at the configuration level or via the *cis_level* attribute at the object (resource) level.

#### For Compute:
##### CIS profile level "1": 
  - in-transit encryption is enforced.

##### CIS profile level "2": 
  - encryption at rest with customer managed keys is enforced.
  - secure boot (Shielded instance) is enforced. 
  - legacy v1 Metadata service endpoint is disabled.

#### For Block Volumes and File Storage:
##### CIS profile level "2": 
  - encryption at rest with customer managed keys is enforced.

### <a name="compute-1">Compute</a>

Compute instances are managed using the **instances_configuration** variable. It contains a set of attributes starting with the prefix **default_** and one attribute named **instances**. The **default_** attribute values are applied to all instances within **instances**, unless overridden at the instance level.

The *default_* attributes are the following:
- **default_compartment_id** &ndash; Default compartment for all instances. It can be overridden by *compartment_id* attribute in each instance. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **default_subnet_id** &ndash; (Optional) Default subnet for all instances. It can be overridden by *subnet_id* attribute in each instance. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *network_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **default_ssh_public_key_path** &ndash; (Optional) Default SSH public key path used to access all instances. It can be overridden by the *ssh_public_key* attribute in each instance.
- **default_kms_key_id** &ndash; (Optional) Default encryption key for all instances. It can be overridden by *kms_key_id* attribute in each instance. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *kms_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **default_cis_level** &ndash; (Optional) Default CIS OCI Benchmark profile level for all instances. Level "2" enforces usage of customer managed keys for boot volume encryption. Default is "1". It can be overridden by *cis_level* attribute in each instance.
- **default_defined_tags** &ndash; (Optional) Default defined tags for all instances. It can be overridden by *defined_tags* attribute in each instance.
- **default_freeform_tags** &ndash; (Optional) Default freeform tags for all instances. It can be overridden by *freeform_tags* attribute in each instance.
- **default_cloud_init_heredoc_script** &ndash; (Optional) Default cloud-init script in [Terraform heredoc style](https://developer.hashicorp.com/terraform/language/expressions/strings#heredoc-strings) that is applied to all instances. It has precedence over *default_cloud_init_script_file*. Use this when the script cannot be made available in the file system. **Any further changes to the script triggers instance recreation on subsequent plan/apply.**
- **default_cloud_init_script_file** &ndash; (Optional) Default cloud-init script file that is applied to all instances. Use this when the script is available in the file system. **Any further changes to the script triggers instance recreation on subsequent plan/apply.**

The instances themselves are defined within the **instances** attribute, In Terraform terms, it is a map of objects. where each object is referred by an identifying key. The supported attributes are listed below. For better usability, most attributes are grouped in logical blocks. They are properly indented in the list.
- **compartment_id** &ndash; (Optional) The instance compartment. *default_compartment_id* is used if undefined. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **cis_level** &ndash; (Optional) The CIS OCI Benchmark profile level to apply. *default_cis_level* is used if undefined.
- **shape** &ndash; The instance shape. See [Compute Shapes](https://docs.oracle.com/en-us/iaas/Content/Compute/References/computeshapes.htm) for OCI Compute shapes.
- **name** &ndash; The instance name.
- **platform_type** &ndash; (Optional) The platform type. Assigning this attribute enables important platform security features in the Compute service. See [Enabling Platform Features](#platform-features) for more information. Valid values are "AMD_MILAN_BM", "AMD_MILAN_BM_GPU", "AMD_ROME_BM", "AMD_ROME_BM_GPU", "AMD_VM", "GENERIC_BM", "INTEL_ICELAKE_BM", "INTEL_SKYLAKE_BM", "INTEL_VM". By default, no platform features are enabled.
- **cluster_id** &ndash; (Optional) The Compute cluster the instance is added to. It can take either a literal cluster OCID or cluster key defined in the *clusters_configuration* variable.
- **ssh_public_key_path** &ndash; (Optional) The SSH public key path used to access the instance. *default_ssh_public_key_path* is used if undefined.
- **defined_tags** &ndash; (Optional) The instance defined tags. *default_defined_tags* is used if undefined.
- **freeform_tags** &ndash; (Optional) The instance freeform tags. *default_freeform_tags* is used if undefined.
- **marketplace_image** &ndash; (Optional) The Marketplace image information. *name* is required, *version* is optional. If *version* is not provided, the latest available version is used. See [Obtaining OCI Marketplace Images Information](#marketplace-images) for how to get OCI Marketplace images. **Use one of *marketplace_image*, *platform_image* or *custom_image*.**
  - **name** &ndash; The Marketplace image name.
  - **version** &ndash; (Optional) The Marketplace image version. If not provided, the latest available version is used. For versions with empty spaces, like "7.4.3 ( X64 )", replace any empty spaces by the _ character, so it becomes "7.4.3\_(\_X64\_)".
- **platform_image** &ndash; (Optional) The platform image information. Either the *ocid* or *name* must be provided. See [Obtaining OCI Platform Images Information](#platform-images) for how to get OCI Platform images. **Use one of *marketplace_image*, *platform_image* or *custom_image*.**
  - **ocid** &ndash; (Optional) The Platform image ocid. It takes precedence over name.
  - **name** &ndash; (Optional) The Platform image name. If *name* is provided, variable *tenancy_ocid* is required for looking up the image.
- **custom_image** &ndash; (Optional) The custom image information. Either the *ocid* or (*name* and *compartment_id*) must be provided. **Use one of *marketplace_image*, *platform_image* or *custom_image*.**
  - **ocid** &ndash; (Optional) The custom image ocid. It takes precedence over name.
  - **name** &ndash; (Optional) The custom image name.
  - **compartment_id** &ndash; (Optional) The custom image compartment. It is required if name is used.
- **placement** &ndash; (Optional) Instance placement settings.
  - **availability_domain** &ndash; (Optional) The instance availability domain. Default is 1.
  - **fault_domain** &ndash; (Optional) The instance fault domain. Default is 1.
- **boot_volume** &ndash; (Optional) Boot volume settings.
  - **type** &ndash; (Optional) Boot volume emulation type. Valid values: "paravirtualized", "scsi", "iscsi", "ide", "vfio". Default is "paravirtualized".
  - **firmware** &ndash; (Optional) Firmware used to boot the VM. Valid options: "BIOS" (compatible with both 32 bit and 64 bit operating systems that boot using MBR style bootloaders), "UEFI_64" (default for platform images).
  - **size** &ndash; (Optional) Boot volume size. Default is 50 (in GB, the minimum allowed by OCI).
  - **preserve_on_instance_deletion** &ndash; (Optional) Whether to preserve boot volume after deletion. Default is true.
  - **secure_boot** &ndash; (Optional) Prevents unauthorized boot loaders and operating systems from booting. Default is false. Only applicable if *platform_type* is set.
  - **measured_boot** &ndash; (Optional) enhances boot security by taking and storing measurements of boot components, such as bootloaders, drivers, and operating systems. Bare metal instances do not support Measured Boot. Default is false. Only applicable if *platform_type* is set.
  - **trusted_platform_module** &ndash; (Optional) Used to securely store boot measurements. Default is false. Only applicable if *platform_type* is set.
  - **backup_policy** &ndash; (Optional) The Oracle managed backup policy for the boot volume. Valid values: "gold", "silver", "bronze". Default is "bronze".
- **volumes_emulation_type** &ndash; (Optional) emulation type for attached storage volumes. Valid values: "paravirtualized" (default), "scsi", "iscsi", "ide", "vfio". 
- **networking** &ndash; (Optional) Networking settings. 
  - **type** &ndash; (Optional) Emulation type for the physical network interface card (NIC). Valid values: "paravirtualized" (default), "vfio" (SR-IOV networking), "e1000" (compatible with Linux e1000 driver).
  - **private_ip** &ndash; (Optional) A private IP address of your choice to assign to the primary VNIC. If not provided, an IP address from the subnet is randomly chosen.
  - **hostname** &ndash; (Optional) The primary VNIC hostname.
  - **assign_public_ip** &ndash; (Optional) Whether to assign the primary VNIC a public IP. Default is false.
  - **subnet_id** &ndash; (Optional) The subnet where the primary VNIC is created. *default_subnet_id* is used if undefined. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *network_dependency* variable. See [External Dependencies](#ext-dep) for details.
  - **network_security_groups** &ndash; (Optional) List of network security groups the primary VNIC should be placed into. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *network_dependency* variable. See [External Dependencies](#ext-dep) for details.
  - **skip_source_dest_check** &ndash; (Optional) Whether the source/destination check is disabled on the primary VNIC. If true, the VNIC is able to forward the packet. Default is false.
  - **secondary_ips** &ndash; (Optional) Map of secondary private IP addresses for the primary VNIC.
    - **display_name** &ndash; (Optional) Secondary IP display name.
    - **hostname** &ndash; (Optional) Secondary IP host name.
    - **private_ip** &ndash; (Optional) Secondary IP address. If not provided, an IP address from the subnet is randomly chosen.
    - **defined_tags** &ndash; (Optional) Secondary IP defined_tags. default_defined_tags is used if undefined.
    - **freeform_tags** &ndash; (Optional) Secondary IP freeform_tags. default_freeform_tags is used if undefined.
  - **secondary_vnics** &ndash; (Optional) Map of secondary VNICs attached to the instance
    - **display_name** &ndash; (Optional) The VNIC display name.
    - **private_ip** &ndash; (Optional) a private IP address of your choice to assign to the VNIC. If not provided, an IP address from the subnet is randomly chosen.
    - **hostname** &ndash; (Optional) The VNIC hostname.
    - **assign_public_ip**&ndash; (Optional) Whether to assign the VNIC a public IP. Defaults to whether the subnet is public or private.
    - **subnet_id** &ndash; (Optional) The subnet where the VNIC is created. default_subnet_id is used if undefined.
    - **network_security_groups** &ndash; (Optional) List of network security groups the VNIC should be placed into.
    - **skip_source_dest_check** &ndash; (Optional) Whether the source/destination check is disabled on the VNIC. If true, the VNIC is able to forward the packet. Default is false.
    - **nic_index** &ndash; (Optional) The physical network interface card (NIC) the VNIC will use. Defaults to 0. Certain bare metal instance shapes have two active physical NICs (0 and 1).
    - **security** &ndash; (Optional) Security settings for the VNIC, currently only for ZPR (Zero Trust Packet Routing) attributes.
      - **zpr_attributes** &ndash; (Optional) List of objects representing ZPR attributes.
        - **namespace** &ndash; (Optional) ZPR namespace. Default is *oracle-zpr*, a default namespace created by Oracle and available in all tenancies.
        - **attr_name** &ndash; ZPR attribute name. It must exist in the specified namespace.
        - **attr_value** &ndash; ZPR attribute value.
        - **mode** &ndash; (Optional) ZPR mode. Default value is *enforce*.
    - **secondary_ips** &ndash; (Optional) Map of secondary private IP addresses for the VNIC.
      - **display_name** &ndash; (Optional) Secondary IP display name.
      - **hostname** &ndash; (Optional) Secondary IP host name.
      - **private_ip** &ndash; (Optional) Secondary IP address. If not provided, an IP address from the subnet is randomly chosen.
      - **defined_tags** &ndash; (Optional) Secondary IP defined_tags. default_defined_tags is used if undefined.
      - **freeform_tags** &ndash; (Optional) Secondary IP freeform_tags. default_freeform_tags is used if undefined.  
- **security** &ndash; (Optional) Security settings for the instance, currently only for ZPR (Zero Trust Packet Routing) attributes.
  - **apply_to_primary_vnic_only** &ndash; (Optional) Whether ZPR attributes are applied to the instance primary VNIC only. The default value is false, meaning ZPR attributes are applied to the instance itself (a.k.a. parent resource),thus inherited by all VNICs that are attached to the instance. Set this value to true to stop the inheritance, thus making ZPR attributes applied to the instance primary VNIC only.
  - **zpr_attributes** &ndash; (Optional) List of objects representing ZPR attributes.
    - **namespace** &ndash; (Optional) ZPR namespace. Default is *oracle-zpr*, a default namespace created by Oracle and available in all tenancies.
    - **attr_name** &ndash; ZPR attribute name. It must exist in the specified namespace.
    - **attr_value** &ndash; ZPR attribute value.
    - **mode** &ndash; (Optional) ZPR mode. Default value is *enforce*.  
- **encryption** &ndash; (Optional) Encryption settings. See section [In Transit Encryption](#in-transit-encryption) for important information.
  - **kms_key_id** &ndash; (Optional) The encryption key for boot volume encryption. *default_kms_key_id* is used if undefined. Required if *cis_level* or *default_cis_level* is "2".
  - **encrypt_in_transit_on_instance_create** &ndash; (Optional) Whether to enable in-transit encryption for the data volume's paravirtualized attachment. Default is false. Applicable during instance **creation** time only. Note that some platform images do not allow instances overriding the image configuration for in-transit encryption at instance creation time. In such cases, for enabling in-transit encryption, use *encrypt_in_transit_on_instance_update* attribute. First run ```terraform apply``` with it set to false, then run ```terraform apply``` again with it set to true.
  - **encrypt_in_transit_on_instance_update** &ndash; (Optional) Whether to enable in-transit encryption for the data volume's paravirtualized attachment. Default is false. Applicable during instance **update** time only.
  - **encrypt_data_in_use** &ndash; (Optional) Whether the instance encrypts data in-use (in memory) while being processed (also known as *Confidential Computing*). Default is false. Only applicable if *platform_type* is set.
- **flex_shape_settings** &ndash; (Optional) Flex shape settings.
  - **memory** &ndash; (Optional) The instance memory for Flex shapes. Default is 16 (in GB).
  - **ocpus** &ndash; (Optional) The number of OCPUs for Flex shapes. Default is 1.
- **cloud_agent** &ndash; (Optional) Cloud Agent settings. Oracle Cloud Agent is supported on current platform images and on custom images that are based on current platform images. See [Cloud Agent Requirements](#cloud-agent-requirements) for basic requirements.
  - **disable_management** &ndash; (Optional) Whether the management plugins should be disabled. These plugins are enabled by default in the Compute service. The management plugins are "OS Management Service Agent" and "Compute Instance Run Command".
  - **disable_monitoring** &ndash; (Optional) Whether the monitoring plugins should be disabled. These plugins are enabled by default in the Compute service. The monitoring plugins are "Compute Instance Monitoring" and "Custom Logs Monitoring".
  - **plugins** &ndash; (Optional) The list of plugins to manage. Each plugin has a name and a boolean flag that enables it.
    - **name** &ndash; The plugin name. **It must be a valid plugin name**. The plugin names are available in [Oracle Cloud Agent documentation](https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/manage-plugins.htm) and in [compute-only example](./examples/compute-only/input.auto.tfvars.template) as well.
    - **enabled** &ndash; Whether or not the plugin should be enabled. In order to disable a previously enabled plugin, set this value to false. Simply removing the plugin from the list will not disable it.
- **cloud_init** &ndash; (Optional) a script that is automatically executed once the instance starts out. Use either *heredoc_script* (when the script cannot be made available in the file system) or *script_file* (when the script is available in the file system). **Any further changes to the script (supplied in either way) triggers instance recreation on subsequent plan/apply.**
  - **heredoc_script** &ndash; (Optional) cloud-init script in [Terraform heredoc style](https://developer.hashicorp.com/terraform/language/expressions/strings#heredoc-strings) that is applied to the instance. It has precedence over *script_file*.
  - **script_file** &ndash; (Optional) cloud-init script file that is applied to the instance.    

#### <a name="cloud-agent-requirements">Cloud Agent Requirements</a>
##### IAM Policy Requirements
The ability to enable/disable/start/stop plugins require the following policy statements for the executing user, as documented in the [Requirements](#requirements) section above.
```
Allow group <GROUP-NAME> to manage instance-family in compartment <INSTANCE-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to read instance-agent-plugins in compartment <INSTANCE-COMPARTMENT-NAME> 
```
##### Network Requirements
The subnet where the instance is deployed must have access to Oracle Services Network. Make sure there is a network route and an egress security rule to *all regional services In Oracle Services Network* through the VCN Service Gateway.

Please see [Oracle Cloud Agent documentation](https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/manage-plugins.htm) for other important information.

#### <a name="platform-features">Enabling Platform Features</a>
The module currently supports [Confidential computing](https://docs.oracle.com/en-us/iaas/Content/Compute/References/confidential_compute.htm) and [Shielded instances](https://docs.oracle.com/en-us/iaas/Content/Compute/References/shielded-instances.htm), which cannot be enabled at the same time.
- Confidential computing usage is controlled by *platform_type* and *encryption.encrypt_data_in_use* attributes. 
- Confidential computing is only available for the shapes listed in [Compute Shapes that Support Confidential Computing](https://docs.oracle.com/en-us/iaas/Content/Compute/References/confidential_compute.htm#confidential_compute__coco_supported_shapes).
- Shielded instances usage is controlled by *platform_type*, *boot_volume.secure_boot*, *boot_volume.measured_boot* and *boot_volume.trusted_platform_module* attributes. For supported VM shapes, *boot_volume.measured_boot* value is used to set both *boot_volume.secure_boot* and *boot_volume.trusted_platform_module* attributes. 
- Shielded instances are only available for the shapes and images listed in [Supported Shapes and Images](https://docs.oracle.com/en-us/iaas/Content/Compute/References/shielded-instances.htm#supported-shapes).
- Shielded instances are automatically enabled if CIS Profile level is "2" (either via *cis_level* or *default_cis_level* attributes).

#### <a name="platform-images">Obtaining OCI Platform Images Information</a>
Helper module [platform-images](../platform-images/) aids in finding OCI Platform instances based on a search string. See [this example](../platform-images/examples/platform-images/) for finding images containing "Linux-8" in their names. It outputs information as shown below.

**Note:** It also outputs the compatible shapes for each image. 

```
Display Name: Oracle-Linux-8.8-2023.08.31-0
Publisher Name: Oracle
Id: ocid1.image.oc1.iad.aaaaaaaamf35m2qg5krijvq4alf6qmvdqiroq4i5zdwqqdijmstn4ryes36q
Operating System: Oracle Linux
Operating System Version: 8
Is encryption in transit enabled? true
State: AVAILABLE
Compatible shapes: VM.DenseIO.E4.Flex, VM.DenseIO1.16, VM.DenseIO1.4, VM.DenseIO1.8, VM.DenseIO2.16, VM.DenseIO2.24, VM.DenseIO2.8, VM.GPU.A10.1, VM.GPU.A10.2, VM.GPU.GU1.1, VM.GPU.GU1.2, VM.GPU2.1, VM.GPU3.1, VM.GPU3.2, VM.GPU3.4, VM.Optimized3.Flex, VM.Standard.AMD.Generic, VM.Standard.B1.1, VM.Standard.B1.16, VM.Standard.B1.2, VM.Standard.B1.4, VM.Standard.B1.8, VM.Standard.E2.1, VM.Standard.E2.1.Micro, VM.Standard.E2.2, VM.Standard.E2.4, VM.Standard.E2.8, VM.Standard.E3.Flex, VM.Standard.E4.Flex, VM.Standard.E5.Flex, VM.Standard.Intel.Generic, VM.Standard.x86.Generic, VM.Standard1.1, VM.Standard1.16, VM.Standard1.2, VM.Standard1.4, VM.Standard1.8, VM.Standard2.1, VM.Standard2.16, VM.Standard2.2, VM.Standard2.24, VM.Standard2.4, VM.Standard2.8, VM.Standard2.Flex, VM.Standard3.Flex, BM.Standard.E2.64, BM.Standard.E3.128, BM.Standard.E4.128, BM.GPU.B4.8, BM.GPU.A100-v2.8, BM.DenseIO.E4.128, BM.DenseIO.E5.128, BM.Standard.E5.192, BM.Standard1.36, BM.HighIO1.36, BM.DenseIO1.36, BM.Standard.B1.44, BM.GPU2.2, BM.HPC2.36, BM.Standard2.52, BM.GPU3.8, BM.DenseIO2.52, BM.GPU.T1.2, BM.Optimized3.36, BM.Standard3.64, BM.GPU.A10.4

Display Name: Oracle-Linux-8.8-2023.08.16-0
Publisher Name: Oracle
Id: ocid1.image.oc1.iad.aaaaaaaaj3fbxkn7ql2l4zvdio7atzczezg6dv5dncmz247wfoaqgfgyagaq
Operating System: Oracle Linux
Operating System Version: 8
Is encryption in transit enabled? true
State: AVAILABLE
Compatible shapes: VM.DenseIO.E4.Flex, VM.DenseIO1.16, VM.DenseIO1.4, VM.DenseIO1.8, VM.DenseIO2.16, VM.DenseIO2.24, VM.DenseIO2.8, VM.GPU.A10.1, VM.GPU.A10.2, VM.GPU.GU1.1, VM.GPU.GU1.2, VM.GPU2.1, VM.GPU3.1, VM.GPU3.2, VM.GPU3.4, VM.Optimized3.Flex, VM.Standard.AMD.Generic, VM.Standard.B1.1, VM.Standard.B1.16, VM.Standard.B1.2, VM.Standard.B1.4, VM.Standard.B1.8, VM.Standard.E2.1, VM.Standard.E2.1.Micro, VM.Standard.E2.2, VM.Standard.E2.4, VM.Standard.E2.8, VM.Standard.E3.Flex, VM.Standard.E4.Flex, VM.Standard.E5.Flex, VM.Standard.Intel.Generic, VM.Standard.x86.Generic, VM.Standard1.1, VM.Standard1.16, VM.Standard1.2, VM.Standard1.4, VM.Standard1.8, VM.Standard2.1, VM.Standard2.16, VM.Standard2.2, VM.Standard2.24, VM.Standard2.4, VM.Standard2.8, VM.Standard2.Flex, VM.Standard3.Flex, BM.Standard.E2.64, BM.Standard.E3.128, BM.Standard.E4.128, BM.GPU.B4.8, BM.GPU.A100-v2.8, BM.DenseIO.E4.128, BM.Standard.E5.192, BM.Standard1.36, BM.HighIO1.36, BM.DenseIO1.36, BM.Standard.B1.44, BM.GPU2.2, BM.HPC2.36, BM.Standard2.52, BM.GPU3.8, BM.DenseIO2.52, BM.GPU.T1.2, BM.Optimized3.36, BM.Standard3.64, BM.GPU.A10.4

...
```
Use *Id* value to seed the *image.id* attribute. Use one of the *Compatible shapes* value to seed *shape* attribute.

#### <a name="marketplace-images">Obtaining OCI Marketplace Images Information</a>
Helper module [marketplace-images](../marketplace-images/) aids in finding Compute images in OCI Marketplace based on a search string. See [this example](../marketplace-images/examples/marketplace-images/) for finding images containing "CIS" in their names. It outputs information like:
```
Publisher: Center for Internet Security
Image name: CIS CentOS Linux 6 Benchmark - Level 1
Listing resource id: ocid1.image.oc1..aaaaaaaasxmjh33hefbbfbstzr6xmtfxfi4vkqeq5xg5kpghdxw3msnn4ycq
Resource version: 2.0.2.13

Publisher: Center for Internet Security
Image name: CIS CentOS Linux 7 Benchmark - Level 1
Listing resource id: ocid1.image.oc1..aaaaaaaaxmhng6g2j5vi7o4wb5sopjz73zhsiswrvpgq4b3rnemlqupuq3pa
Resource version: 3.1.2.6
...
```
Use the *Listing resource id* or *Image name* and *Publisher* to seed *image.id* or the *image.name* and *image.publisher* attributes.

#### <a name="in-transit-encryption">In Transit Encryption</a>
As stated in the [OCI User Guide](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/overview.htm#BlockVolumeEncryption):

*"In-transit encryption for boot and block volumes is only available for virtual machine (VM) instances launched from platform images, along with bare metal instances that use the following shapes: BM.Standard.E3.128, BM.Standard.E4.128, BM.DenseIO.E4.128. It is not supported on other bare metal instances. To confirm support for certain Linux-based custom images and for more information, contact Oracle support."*

Additionally, in-transit encryption is only available to paravirtualized volumes (boot and block volumes).

**Note:** platform images may not allow instances overriding the image configuration for in-transit encryption at instance launch time. In such cases, there are two options for enabling in-transit encryption:
1. Set *encryption.encrypt_in_transit_on_instance_create* attribute to true. This attribute is **only applicable** when the instance is **initially** provisioned.
2. On any updates to the instance, set *encryption.encrypt_in_transit_on_instance_update* attribute to true. This attribute **must not** be set when the instance is initially provisioned.

### <a name="storage">Storage</a>

Storage is managed using the **storage_configuration** variable. It contains a set of attributes starting with the prefix **default_** and two attribute named **block_volumes** and **file_storage**. The **default_** attribute values are applied to all storage units within **block_volumes** and **file_storage**, unless overridden at the storage unit level.

The defined **default_** attributes are the following:
- **default_compartment_id** &ndash; (Optional) The default compartment for all storage units. It can be overridden by *compartment_id* attribute in each unit. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **default_kms_key_id** &ndash; (Optional) The default encryption key for all storage units. It can be overridden by *kms_key_id* attribute in each unit. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *kms_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **default_cis_level** &ndash; (Optional) The default CIS OCI Benchmark profile level for all storage units. Level "2" enforces usage of customer managed keys for storage encryption. Default is "1". It can be overridden by *cis_level* attribute in each unit.
- **default_defined_tags** &ndash; (Optional) The default defined tags for all storage units. It can be overridden by *defined_tags* attribute in each unit.
- **default_freeform_tags** &ndash; (Optional) the default freeform tags for all storage units. It can be overridden by *freeform_tags* attribute in each unit.

#### <a name="block-volumes-1">Block Volumes</a>
Block volumes are defined using the optional **block_volumes** attribute. In Terraform terms, it is a map of objects, where each object is referred by an identifying key. The following attributes are supported:
- **compartment_id** &ndash; (Optional) The volume compartment. The *default_compartment_id* is used if undefined. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **cis_level** &ndash; (Optional) The CIS OCI Benchmark profile level to apply. The *default_cis_level* is used if undefined.
- **display_name** &ndash; The volume display name.
- **availability_domain** &ndash; (Optional) The volume availability domain. Default is 1.
- **volume_size** &ndash; (Optional) The volume size. Default is 50 (GB).
- **vpus_per_gb** &ndash; (Optional) The number of VPUs per GB of volume. Values are 0(LOW), 10(BALANCE), 20(HIGH), 30-120(ULTRA HIGH). Default is 0.
- **defined_tags** &ndash; (Optional) The volume defined tags. The *default_defined_tags* is used if undefined.
- **freeform_tags** &ndash; (Optional) The volume freeform tags. The *default_freeform_tags* is used if undefined.
- **attach_to_instances** &ndash; (Optional) A list with instance attachments. Each element defines an attachment. If more than one attachment is defined for a volume, all attachments are automatically configured as shareable. Note that the module does **not** mount the block volume in the instances. For instructions how to mount block volumes, please section [Mounting Block Volumes](#mounting-block-volumes).
  - **instance_id** &ndash; The instance that the volume attaches to. It must be one of the identifying keys in the *instances* map or in the *instances_dependency* variable. See [External Dependencies](#ext-dep) for details.
  - **device_name** &ndash; The device name where to mount the block volume. It must be one of the *disk_mappings* value in the *instances* map or in the *instances_dependency* object.
  - **attachment_type** &ndash; (Optional) The block volume attachment type. Valid values: "paravirtualized" (default), "iscsi".
  - **read_only** &ndash; (Optional) The attachment access mode. Default is false, which means attachments are "Read/Write" by default.
- **encryption** &ndash; (Optional) Encryption settings
  - **kms_key_id** &ndash; (Optional) The encryption key for volume encryption. *default_kms_key_id* is used if undefined. Required if *cis_level* or *default_cis_level* is "2". This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *kms_dependency* variable. See [External Dependencies](#ext-dep) for details.
  - **encrypt_in_transit** &ndash; (Optional) Whether traffic encryption should be enabled for the volume. Only applicable for "paravirtualized" attachment type. Default is false.
- **replication** &ndash; (Optional) Replication settings
  - **availability_domain** &ndash; The availability domain (AD) to replicate the volume. The AD is picked from the region set by the module client to *block_volumes_replication_region* provider alias. Check [here](./examples/storage-only/) for an example with cross-region replication.
- **backup_policy** &ndash; (Optional) The Oracle managed backup policy for the volume. Valid values: "gold", "silver", "bronze". Default is "bronze".

##### <a name="mounting-block-volumes">Mounting Block Volumes</a>
As stated in the [OCI User Guide](https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/attachingavolume.htm):

*"On Linux-based instances, if you want to automatically mount volumes when the instance starts, you need to set some specific options in the /etc/fstab file, or the instance might fail to start. This applies to both iSCSI and paravirtualized attachment types."*
In case of the ISCSI attachment type, you need to connect to the Block Volume before mounting it. This can be done automatically by enabling the **Block Volume Management** agent on the Instances where you want to mount Block Volumes. Volumes attached with Paravirtualized are automatically connected.

- **For volumes that use consistent device path see the following steps**:

1. To verify that the volume is attached to a supported instance, connect to the instance and run the following command:
```
ll /dev/oracleoci/oraclevd*
```
The output will look similar to the following:
```
lrwxrwxrwx. 1 root root 6 Oct  6 08:17 /dev/oracleoci/oraclevda -> ../sda
lrwxrwxrwx. 1 root root 7 Oct  6 08:17 /dev/oracleoci/oraclevda1 -> ../sda1
lrwxrwxrwx. 1 root root 7 Oct  6 08:17 /dev/oracleoci/oraclevda2 -> ../sda2
lrwxrwxrwx. 1 root root 7 Oct  6 08:17 /dev/oracleoci/oraclevda3 -> ../sda3
```

2. To see the volumes attached to the instance, run the following command:
```
lsblk
```
The output will look similar to the following:
```
NAME               MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                  8:0    0 46.6G  0 disk
├─sda1               8:1    0  100M  0 part /boot/efi
├─sda2               8:2    0    1G  0 part /boot
└─sda3               8:3    0 45.5G  0 part
  ├─ocivolume-root 252:0    0 35.5G  0 lvm  /
  └─ocivolume-oled 252:1    0   10G  0 lvm  /var/oled
sdb                  8:16   0   75G  0 disk
```
 **sda** is the root volume.
 **sdb** is the block volume.

3. Create the filesystem of your choice on the volume. If a file system already exists on the volume, you don't need to create another one.
Example to create a filesystem:
```
sudo parted /dev/oracleoci/oraclevdb  --script -- mklabel gpt
sudo parted /dev/oracleoci/oraclevdb  --script -- mkpart primary 0% 100%
sudo mkfs.ext4 /dev/oracleoci/oraclevdb1
```
Running the **lsblk** command again, you will see an output similar to the following:
```
NAME               MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                  8:0    0 46.6G  0 disk
├─sda1               8:1    0  100M  0 part /boot/efi
├─sda2               8:2    0    1G  0 part /boot
└─sda3               8:3    0 45.5G  0 part
  ├─ocivolume-root 252:0    0 35.5G  0 lvm  /
  └─ocivolume-oled 252:1    0   10G  0 lvm  /var/oled
sdb                  8:16   0   75G  0 disk
└─sdb1               8:17   0   75G  0 part
```
**sdb1** is the partition of the **sdb** block volume.

4. To automatically attach the block volume at /mnt/vol1, create the directory with the following command:
```
sudo mkdir /mnt/vol1
```

5. Add an entry in the /etc/fstab with the following format to automatically mount the block volume after reboot:
```
/dev/oracleoci/oraclevdb1 /mnt/vol1 ext4 defaults,_netdev,nofail 0 2
```
The **ext4** option is the filesystem type you set when you created the filesystem.
The **_netdev** option is to configure the mount process to initiate before the volumes are mounted.
The **nofail** option is to prevent an issue when you create a custom image of an instance where the volumes, excluding the root volume, are listed in the /etc/fstab file, instances will fail to launch from the custom image.

6. Run the following command to update the systemd after you modified the fstab:
```
sudo systemctl daemon-reload
```

7. Mount the volume by running the following commands to mount and check if the volume has been mounted:
```
sudo mount -a
lsblk
```
The output will look similar to the following:
```
sda                  8:0    0 46.6G  0 disk
├─sda1               8:1    0  100M  0 part /boot/efi
├─sda2               8:2    0    1G  0 part /boot
└─sda3               8:3    0 45.5G  0 part
  ├─ocivolume-root 252:0    0 35.5G  0 lvm  /
  └─ocivolume-oled 252:1    0   10G  0 lvm  /var/oled
sdb                  8:16   0   75G  0 disk
└─sdb1               8:17   0   75G  0 part /mnt/vol1
```

8. You can test if the volume is mounted by restarting the instance and run the **lsblk** command.

For more information on mounting block volumes with consistent device path see [fstab Options for Block Volumes Using Consistent Device Paths](https://docs.oracle.com/en-us/iaas/Content/Block/References/fstaboptionsconsistentdevicepaths.htm#fstab_Options_for_Block_Volumes_Using_Consistent_Device_Paths).

- **For volumes that don't use consistent device path:**

On Linux operating systems, the order in which volumes are attached is non-deterministic, so it can change with each reboot. If you refer to a volume using the device name, such as /dev/sdb, and you have more than one non-root volume, you can't guarantee that the volume you intend to mount for a specific device name will be the volume mounted.
To prevent this issue, specify the volume UUID in the /etc/fstab file instead of the device name. When you use the UUID, the mount process matches the UUID in the superblock with the mount point specified in the /etc/fstab file. This process guarantees that the same volume is always mounted to the same mount point.
See the following steps for mounting traditional volumes:

1. To see the volumes attached to the instance, run the following command:
```
lsblk
```
The output will look similar to the following:
```
NAME               MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                  8:0    0 46.6G  0 disk
├─sda1               8:1    0  100M  0 part 
├─sda2               8:2    0    1G  0 part
└─sda3               8:3    0 45.5G  0 part
  ├─ocivolume-root 252:0    0 35.5G  0 lvm  /
  └─ocivolume-oled 252:1    0   10G  0 lvm  /var/oled
sdb                  8:16   0   60G  0 disk
```
 **sda** is the root volume.
 **sdb** is the block volume.

2. Create the filesystem of your choice on the volume. If a file system already exists on the volume, you don't need to create another one.

Example to create a filesystem:
```
sudo parted /dev/sdb --script -- mklabel gpt
sudo parted /dev/sdb  --script -- mkpart primary 0% 100%
sudo mkfs.xfs /dev/sdb1
```
Running the **lsblk** command again, you will see an output similar to the following:
```
NAME               MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                  8:0    0 46.6G  0 disk
├─sda1               8:1    0  100M  0 part
├─sda2               8:2    0    1G  0 part
└─sda3               8:3    0 45.5G  0 part
  ├─ocivolume-root 252:0    0 35.5G  0 lvm  /
  └─ocivolume-oled 252:1    0   10G  0 lvm  /var/oled
sdb                  8:16   0   60G  0 disk
└─sdb1               8:17   0   60G  0 part
```
**sdb1** is the partition of the **sdb** block volume.

3. Run the following command to get the UUIDs for the volumes:
```
sudo blkid
```
The output will look similar to the following:
```
/dev/mapper/ocivolume-oled: UUID="b19c85cf-53cb-4cf3-a2f5-946d7a30bbf0" BLOCK_SIZE="4096" TYPE="xfs"
/dev/sda3: UUID="xW7hJV-XCVZ-zI0I-qhp7-mLnH-3oDH-hppEqq" TYPE="LVM2_member" PARTUUID="8bb84ab7-f5df-47f1-b630-21442c9102c1"
/dev/sda1: SEC_TYPE="msdos" UUID="A1B2-7E6F" BLOCK_SIZE="512" TYPE="vfat" PARTLABEL="EFI System Partition" PARTUUID="ceb6c9aa-4543-4cbf-a44e-d75d7bddc644"
/dev/sda2: UUID="3f9d566b-9964-4512-bcd6-3bb2596d710c" BLOCK_SIZE="4096" TYPE="xfs" PARTUUID="340a48cc-18ed-4c1a-aad7-90cdb8e0b600"
/dev/mapper/ocivolume-root: UUID="9ba90a84-c4e7-447d-bfff-92134fee9387" BLOCK_SIZE="4096" TYPE="xfs"
/dev/sdb1: UUID="3c378562-2bbe-4641-a508-34797d3e198e" BLOCK_SIZE="4096" TYPE="xfs" PARTLABEL="primary" PARTUUID="708ad452-569b-4dfb-b7f0-0b9e38c58157"
```

4. To automatically attach the volume at /mnt/vol1, create the directory with the following command:
```
sudo mkdir /mnt/vol1
```

5. Add an entry in the /etc/fstab with the following format to automatically mount the block volume after reboot:
```
UUID=3c378562-2bbe-4641-a508-34797d3e198e /mnt/vol1 xfs defaults,_netdev,nofail 0 2
```
The **xfs** option is the filesystem type you set when you created the filesystem.
The **_netdev** option is to configure the mount process to initiate before the volumes are mounted.
The **nofail** option is to prevent an issue when you create a custom image of an instance where the volumes, excluding the root volume, are listed in the /etc/fstab file, instances will fail to launch from the custom image.

6. Run the following command to update the systemd after you modified the fstab:
```
sudo systemctl daemon-reload
```

7. Mount the volume by running the following commands to mount and check if the volume has been mounted:
```
sudo mount -a
lsblk
```
The output will look similar to the following:
```
sda                  8:0    0 46.6G  0 disk
├─sda1               8:1    0  100M  0 part /boot/efi
├─sda2               8:2    0    1G  0 part /boot
└─sda3               8:3    0 45.5G  0 part
  ├─ocivolume-root 252:0    0 35.5G  0 lvm  /
  └─ocivolume-oled 252:1    0   10G  0 lvm  /var/oled
sdb                  8:16   0   60G  0 disk
└─sdb1               8:17   0   60G  0 part /mnt/vol1
```

8. You can test if the volume is mounted by restarting the instance and run the **lsblk** command.

For more information on mounting block volumes without consistent device path see [Traditional fstab Options](https://docs.oracle.com/en-us/iaas/Content/Block/References/fstaboptions.htm#Traditional_fstab_Options).


#### <a name="file-storage-1">File Storage</a>
The **file_storage** attribute defines the file systems, mount targets and snapshot policies for OCI File Storage service. The optional attribute **default_subnet_id** applies to all mount targets, unless overridden by **subnet_id** attribute in each mount target. Attribute **subnet_id** is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *network_dependency* variable. See [External Dependencies](#ext-dep) for details.

##### <a name="file-systems">File Systems</a>
File systems are defined using the optional attribute **file_systems**. A Terraform map of objects, where each object is referred by an identifying key. The following attributes are supported:
- **compartment_id** &ndash; The file system compartment. *storage_configuration*'s *default_compartment_id* is used if undefined. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **cis_level** &ndash; (Optional) The CIS OCI Benchmark profile level to apply. *storage_configuration*'s *default_cis_level* is used if undefined.
- **file_system_name** &ndash; The file_system name.
- **availability_domain** &ndash; (Optional) The file system availability domain. 
- **kms_key_id** &ndash; (Optional) The encryption key for file system encryption. *storage_configuration*'s *default_kms_key_id* is used if undefined. Required if *cis_level* or *default_cis_level* is "2". This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *kms_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **replication** &ndash; (Optional) Replication settings. To set the file system as a replication target, set *is_target* to true. To set the file system as a replication source, provide the replication file system target in *file_system_target_id*. A file system cannot be replication source and target at the same time.
  - **is_target** &ndash; (Optional) Whether the file system is a replication target. If this is true, then *file_system_target_id* must not be set. Default is false.
  - **file_system_target_id** &ndash; (Optional) The file system remote replication target for this file system. It must be an existing unexported file system, in the same or in a different region than this file system. If this is set, then *is_target* must be false. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *file_systems_dependency* variable. See [External Dependencies](#ext-dep) for details.
  - **interval_in_minutes** &ndash; (Optional) Time interval (in minutes) between replication snapshots. Default is 60 minutes.
- **snapshot_policy_id** &ndash; (Optional) The snapshot policy identifying key in the *snapshots_policy* map. Default snapshot policies are associated with file systems without a snapshot policy.
- **defined_tags** &ndash; (Optional) File system defined_tags. *storage_configuration*'s *default_defined_tags* is used if undefined.
- **freeform_tags** &ndash; (Optional) File system freeform_tags. *storage_configuration*'s *default_freeform_tags* is used if undefined.

##### <a name="mount-targets">Mount Targets</a>
Mount targets are defined using the optional attribute **mount_targets**. A Terraform map of objects, where each object is referred by an identifying key. The following attributes are supported:
- **compartment_id** &ndash; (Optional) The mount target compartment. *storage_configuration*'s *default_compartment_id* is used if undefined. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **mount_target_name** &ndash; The mount target and export set name.
- **availability_domain** &ndash; (Optional) The mount target availability domain.  
- **subnet_id** &ndash; (Optional) The mount target subnet. It defaults to *default_subnet_id* from *file_storage* if undefined. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *network_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **exports** &ndash; (Optional) List of exports, where each element refers to a file system, defined by *file_system_id* attribute. The following attributes are supported:
  - **path** &ndash; Export path.
  - **file_system_id** &ndash; The file system identifying key this mount target applies.
  - **options** &ndash; (Optional) List of export options.
    - **source** &ndash; The source IP address or CIDR range allowed to access the mount target.
    - **access** &ndash; (Optional) Type of access grants. Valid values (case sensitive): "READ_WRITE", "READ_ONLY". Default is "READ_ONLY".
    - **identity** &ndash; (Optional) UID and GID remapped to. Valid values(case sensitive): ALL, ROOT, NONE. Default is "NONE".
    - **use_port** &ndash; (Optional) Whether file system access is only allowed from a privileged source port. Default is true.

##### <a name="snapshot-policies">Snapshot Policies</a>
Snapshot policies are defined using the optional attribute **snapshot_policies**. A Terraform map of objects, where each object is referred by an identifying key. The following attributes are supported:
- **name** &ndash; The snapshot policy name.
- **compartment_id** &ndash; (Optional) The snapshot policy compartment. The *default_compartment_id* of *storage_configuration* is used if undefined. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **availability_domain** &ndash; (Optional) The snapshot policy availability domain.
- **prefix** &ndash; (Optional) The prefix to apply to all snapshots created by this policy.
- **schedules** &ndash; (Optional) A list of schedules to run the policy. A maximum of 10 schedules can be associated with a policy.
  - **period** &ndash; Valid values: "DAILY", "WEEKLY", "MONTHLY", "YEARLY".
  - **prefix** &ndash; (Optional) A name prefix to be applied to snapshots created by this schedule.
  - **time_zone** &ndash; (Optional) The schedule time zone. Default is "UTC".
  - **hour_of_day** &ndash; (Optional) The hour of the day to create a "DAILY", "WEEKLY", "MONTHLY", or "YEARLY" snapshot. If not set, a value will be chosen at creation time. Default is 23.
  - **day_of_week** &ndash; (Optional) The day of the week to create a scheduled snapshot. Used for "WEEKLY" snapshot schedules. 
  - **day_of_month** &ndash; (Optional) The day of the month to create a scheduled snapshot. If the day does not exist for the month, snapshot creation will be skipped. Used for "MONTHLY" and "YEARLY" snapshot schedules. 
  - **month** &ndash; (Optional) The month to create a scheduled snapshot. Used only for "YEARLY" snapshot schedules. 
  - **retention_in_seconds** &ndash; (Optional) The number of seconds to retain snapshots created with this schedule. Snapshot expiration time is not set if this value is empty. 
  - **start_time** &ndash; (Optional) 1The starting point used to begin the scheduling of the snapshots based upon recurrence string in RFC 3339 timestamp format. If no value is provided, the value is set to the time when the schedule is created. 
- **defined_tags** &ndash; (Optional) Snapshot policy defined tags. *storage_configuration*'s *default_defined_tags* is used if undefined.
- **freeform_tags** &ndash; (Optional) Snapshot policy freeform tags. *storage_configuration*'s *default_freeform_tags* is used if undefined.

As mentioned, default snapshot policies are created for file systems that do not have a snapshot policy. The default snapshot policies are defined with a single schedule, set to run weekly at 23:00 UTC on sundays.


#### <a name="clusters">Clusters</a>

The module can manage cluster networks and compute clusters.

A [cluster network](https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/managingclusternetworks.htm) is a pool of high performance computing (HPC) instances that are connected with a high-bandwidth, ultra low-latency network. They're designed for highly demanding parallel computing jobs.

A [Compute cluster](https://docs.oracle.com/iaas/Content/Compute/Tasks/compute-clusters.htm) is a remote direct memory access (RDMA) network group. You can create high performance computing (HPC) instances in the network and manage them individually.

Clusters are managed using the **clusters_configuration** variable. It contains a set of attributes starting with the prefix **default_** and one attribute named **clusters**. The **default_** attribute values are applied to all clusters within **clusters**, unless overridden at the cluster level.

The *default_* attributes are the following:
- **default_compartment_id** &ndash; Default compartment for all clusters. It can be overridden by *compartment_id* attribute in each cluster. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **default_defined_tags** &ndash; (Optional) Default defined tags for all clusters. It can be overridden by *defined_tags* attribute in each cluster.
- **default_freeform_tags** &ndash; (Optional) Default freeform tags for all clusters. It can be overridden by *freeform_tags* attribute in each cluster.

The clusters themselves are defined within the **clusters** attribute, In Terraform terms, it is a map of objects. where each object is referred by an identifying key. The supported attributes are listed below. For better usability, most attributes are grouped in logical blocks. They are properly indented in the list.

- **compartment_id** &ndash; (Optional) The cluster compartment. *default_compartment_id* is used if undefined. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **type** &ndash; (Optional) The cluster type. Valid values: "cluster_network", "compute_cluster". Default is "cluster_network".
- **availability_domain** &ndash; (Optional) The availability domain for cluster instances. Default is 1.
- **name** &ndash; The cluster display name.
- **defined_tags** &ndash; (Optional) The cluster defined_tags. *default_defined_tags* is used if undefined.
- **freeform_tags** &ndash; (Optional) The cluster freeform_tags. *default_freeform_tags* is used if undefined.
- **cluster_network_settings** &ndash; (Optional) Cluster network settings. **Only applicable if type is "cluster_network"**.
  - **instance_configuration_id** &ndash; The instance configuration id to use in this cluster. It can be a literal OCID or a configuration key defined in *cluster_instances_configuration* variable.
  - **instance_pool** &ndash; (Optional) Cluster instance pool settings.
    - **name** &ndash; (Optional) The instance pool name.
    - **size** &ndash; (Optional) The number of instances in the instance pool. Default is 1.
  - **networking** &ndash; Networking settings.
    - **subnet_id** &ndash; The subnet where instances primary VNIC is placed.
    - **ipv6_enable** &ndash; (Optional) Whether IPv6 is enabled for instances primary VNIC. Default is false.
    - **ipv6_subnet_cidrs** = &ndash; (Optional) A list of IPv6 subnet CIDR ranges from which the primary VNIC is assigned an IPv6 address. Only applicable if ipv6_enable for primary VNIC is true. Default is [].
    - **secondary_vnic_settings** &ndash; (Optional) Secondary VNIC settings
      - **subnet_id** &ndash; The subnet where instances secondary VNIC are created.
      - **name** &ndash; (Optional) The secondary VNIC name.
      - **ipv6_enable** &ndash; (Optional) Whether IPv6 is enabled for the secondary VNIC. Default is false.
      - **ipv6_subnet_cidrs** &ndash; (Optional) A list of IPv6 subnet CIDR ranges from which the secondary VNIC is assigned an IPv6 address. Only applicable if ipv6_enable for secondary VNIC is true. Default is [].

Cluster instance configurations required by cluster networks are managed using the **cluster_instances_configuration** variable. It contains a set of attributes starting with the prefix **default_** and one attribute named **configurations**. The **default_** attribute values are applied to all instance configurations within **configurations**, unless overridden at the configuration level.

The *default_* attributes are the following:
- **default_compartment_id** &ndash; Default compartment for all configurations. It can be overridden by *compartment_id* attribute in each configurations. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **default_defined_tags** &ndash; (Optional) Default defined tags for all configurations. It can be overridden by *defined_tags* attribute in each configuration.
- **default_freeform_tags** &ndash; (Optional) Default freeform tags for all configurations. It can be overridden by *freeform_tags* attribute in each configuration.

The configurations themselves are defined within the **configurations** attribute, In Terraform terms, it is a map of objects. where each object is referred by an identifying key. The supported attributes are listed below.

- **compartment_id** &ndash; (Optional) The compartment where the instance configuration is created. *default_compartment_id* is used if undefined.
- **name** &ndash; (Optional) The instance configuration display name.
- **instance_type** &ndash; (Optional) the instance type. Default is "compute".
- **template_instance_id** &ndash; The existing instance id to use as the configuration template for all instances in the cluster instance pool. It can be a literal instance OCID, an instance key defined in the *instances_configuration* variable, or an instance key defined in the *instances_dependency* variable. 
    **NOTE: The instance must have a <a href='https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/managingclusternetworks.htm#supported-shapes'>shape that supports cluster networks</a>**.
- **defined_tags** &ndash; (Optional) The instance configuration defined_tags. *default_defined_tags* is used if undefined.
- **freeform_tags** &ndash; (Optional) The instance configuration freeform_tags. *default_freeform_tags* is used if undefined.


### <a name="ext-dep">External Dependencies</a>
An optional feature, external dependencies are resources managed elsewhere that resources managed by this module depends on. The following dependencies are supported:

- **compartments_dependency** &ndash; A map of objects containing the externally managed compartments this module depends on. All map objects must have the same type and must contain at least an *id* attribute with the compartment OCID. This mechanism allows for the usage of referring keys (instead of OCIDs) in *default_compartment_id* and *compartment_id* attributes. The module replaces the keys by the OCIDs provided within *compartments_dependency* map. Contents of *compartments_dependency* is typically the output of a [Compartments module](../compartments/) client.

Example:
```
{
	"APP-CMP": {
		"id": "ocid1.compartment.oc1..aaaaaaaa...7xq"
	}
}
```
- **network_dependency** &ndash; A map of map of objects containing the externally managed network resources this module depends on. This mechanism allows for the usage of referring keys (instead of OCIDs) in *default_subnet_id*, *subnet_id* and *network_security_groups* attributes. The module replaces the keys by the OCIDs provided within *network_dependency* map. Contents of *network_dependency* is typically the output of a [Networking module](https://github.com/oracle-quickstart/terraform-oci-cis-landing-zone-networking) client. All map objects must have the same type and should contain the following attributes:
  - An *id* attribute with the subnet OCID.
  - An *id* attribute with the network security group OCID.

Example:
```
{
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
- **kms_dependency** &ndash; A map of objects containing the externally managed encryption keys this module depends on. All map objects must have the same type and must contain at least an *id* attribute with the encryption key OCID. This mechanism allows for the usage of referring keys (instead of OCIDs) in *default_kms_key_id*, and *kms_key_id* attributes. The module replaces the keys by the OCIDs provided within *kms_dependency* map. Contents of *kms_dependency* is typically the output of a [Vault module](https://github.com/oracle-quickstart/terraform-oci-cis-landing-zone-security/tree/main/vaults) client.

Example:
```
{
	"APP-KEY": {
		"id": "ocid1.key.oc1.iad.ejsppeqvaafyi.abuwcl...yna"
	}
}
```
- **instances_dependency** &ndash; A map of objects containing the externally managed instances this module depends on. All map objects must have the same type and must contain at least an *id* attribute with the instance OCID. This mechanism allows for the usage of referring keys (instead of OCIDs) in *instance_id* attributes. The module replaces the keys by the OCIDs provided within *instances_dependency* map. Contents of *instances_dependency* is typically the output of a client of this module.

Example:
```
{
	"INSTANCE-2": {
		"id": "ocid1.instance.oc1.iad.anuwc...ftq",
	}
}
```
- **file_system_dependency** &ndash; A map of objects containing the externally managed file systems this module depends on. All map objects must have the same type and must contain at least an *id* attribute with the file system OCID. This mechanism allows for the usage of referring keys (instead of OCIDs) in *file_system_id* and *file_system_target_id* attributes. The module replaces the keys by the OCIDs provided within *file_system_dependency* map. Contents of *file_system_dependency* is typically the output of a client of this module.

Example:
```
{
	"FILE-SYSTEM-2": {
		"id": "ocid1.filesystem.oc1.iad.aaaaaaaaaae...aaa"
	}
}
```

## <a name="related">Related Documentation</a>
- [Compute Service](https://docs.oracle.com/en-us/iaas/Content/Compute/home.htm)
- [Compute instances in OCI Terraform Provider](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_instance)
- [Block Volume Service](https://docs.oracle.com/en-us/iaas/Content/Block/home.htm)
- [Block Volume in OCI Terraform Provider](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_volume)
- [File Storage Service](https://docs.oracle.com/en-us/iaas/Content/File/home.htm)
- [File Systems in OCI Terraform Provider](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/file_storage_file_system)


## <a name="issues">Known Issues</a>

### Block Volumes
1. The module currently supports only one Block volume replica (within or across regions).
2. Terraform does not destroy replicated Block volumes. It is first necessary to disable replication (for example, in the OCI Console) before running ```terraform destroy```.
3. ```terraform plan``` does not detect the change when switching Block volume encryption from customer-managed key to Oracle-managed key. Use some other means in such cases, like OCI Console or OCI CLI.

### Compute
1. Platform images may not allow instances overriding the image configuration for in-transit encryption at instance launch time. Terraform would typically error out with:
```
Error: 400-InvalidParameter, Overriding PvEncryptionInTransitEnabled in LaunchOptions is not supported
│ Suggestion: Please update the parameter(s) in the Terraform config as per error message Overriding PvEncryptionInTransitEnabled in LaunchOptions is not supported
│ Documentation: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_instance
│ API Reference: https://docs.oracle.com/iaas/api/#/en/iaas/20160918/Instance/LaunchInstance
│ Request Target: POST https://iaas.eu-frankfurt-1.oraclecloud.com/20160918/instances
│ Provider version: 5.13.0, released on 2023-09-13.
│ Service: Core Instance
│ Operation Name: LaunchInstance
│ OPC request ID: 48f751ec9cecd48aa847d726717bfb93/43BFEB13D6C2B12EDB7DD41700D49F55/B0823CBFC3380550DF3506C136D4D7C6
```
In such cases, there are two options for enabling in-transit encryption:
- set *encryption.encrypt_in_transit_on_instance_create* attribute to true. This attribute is only applicable when the instance is initially provisioned.
- on any updates to the instance, set *encryption.encrypt_in_transit_on_instance_update* attribute to true. This attribute **must not** be set when the instance is initially provisioned.

2. As stated in [OCI documentation](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/overview.htm#BlockVolumeEncryption), *"...In-transit encryption for boot and block volumes is only available for virtual machine (VM) instances launched from platform images, along with bare metal instances that use the following shapes: BM.Standard.E3.128, BM.Standard.E4.128, BM.DenseIO.E4.128. It is not supported on other bare metal instances. To confirm support for certain Linux-based custom images and for more information, contact Oracle support..."*

Trying to enable in-transit encryption for a non-platform image will tyically make Terraform error out with:
```
Error: 400-InvalidParameter, Instance ocid1.instance.oc1.iad.anuwcl...34q does not support pv encryption in-transit.        
│ Suggestion: Please update the parameter(s) in the Terraform config as per error message Instance ocid1.instance.oc1.iad.anuwcl...34q does not support pv encryption in-transit.
│ Documentation: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_instance
│ API Reference: https://docs.oracle.com/iaas/api/#/en/iaas/20160918/Instance/LaunchInstance
│ Request Target: POST https://iaas.us-ashburn-1.oraclecloud.com/20160918/instances
│ Provider version: 5.13.0, released on 2023-09-13.
│ Service: Core Instance
│ Operation Name: LaunchInstance
│ OPC request ID: dd06c66b...08f529c0e1718fdcfc/2780B0B7DA...292AD3...E8FE2A/0E9E0694BF...A11E3AF7B2D4DF8
```
In such cases, either remove or set attributes *encrypt_in_transit_on_instance_create* and *encrypt_in_transit_on_instance_update* attributes to false. Or use a platform image.

3. ```terraform apply``` fails when switching boot volume encryption from customer-managed key to Oracle-managed key.
```
Error: 400-InvalidParameter, kmsKeyId is invalid or incorrectly formatted.
│ Suggestion: Please update the parameter(s) in the Terraform config as per error message kmsKeyId is invalid or incorrectly formatted.
│ Documentation: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_instance
│ API Reference: https://docs.oracle.com/iaas/api/#/en/iaas/20160918/BootVolumeKmsKey/UpdateBootVolumeKmsKey
│ Request Target: PUT https://iaas.us-ashburn-1.oraclecloud.com/20160918/bootVolumes/ocid1.bootvolume.oc1.iad.abuwcljr5uxn5ns6atgccav3shq3nnkoouljbmy6ded4hgyrg5ncfb7k3e6a/kmsKey
│ Provider version: 5.13.0, released on 2023-09-13.
│ Service: Core Instance
│ Operation Name: UpdateBootVolumeKmsKey
│ OPC request ID: 3cef1c0e5de57200a960d2593a4e0fa9/FA008B0998DD1B2AC1115316D5ED4D42/19C0164138C36754AC289601BF86FC29
│
│
│   with module.compute.oci_core_instance.these["INSTANCE-1"],
│   on ..\..\compute.tf line 58, in resource "oci_core_instance" "these":
│   58: resource "oci_core_instance" "these" {
```
Use some other means in such cases, like OCI Console or OCI CLI.
