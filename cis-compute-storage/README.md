# Oracle Cloud Infrastructure (OCI) Terraform CIS Compute & Storage (Block Volumes and File System Storage) Module

![Landing Zone logo](../landing_zone_300.png)

This module manages Compute instances, Block Volume and File System Storage in Oracle Cloud Infrastructure (OCI). These resources and their associated resources can be deployed together in the same configuration or separately. The module enforces Center for Internet Security (CIS) Benchmark recommendations for all supported resource types and provides features for strong cyber resilience posture, including cross-region replication and storage backups. Additionally, the module supports bringing in external dependencies that managed resources depend on, including compartments, subnets, network security groups, encryption keys, and others. 

Check [module specification](./SPEC.md) for a full description of module requirements, supported variables, managed resources and outputs.

Check the [examples](./examples/) folder for actual module usage.

- [Features](#features)
- [Requirements](#requirements)
- [Module Functioning](#functioning)
  - [Compute](#compute)
  - [Block Volumes](#block-volumes)
  - [File Storage](#file-storage)
    - [File Systems](#file-systems)
    - [Mount Targets](#mount-targets)
    - [Snapshot Policies](#snapshot-policies)
  - [External Dependencies](#ext-dep)
- [Related Documentation](#related)
- [Known Issues](#issues)

## <a name="features">Features</a>
The following security features are currently supported by the module:

### Compute
- CIS profile level drives data at rest encryption configuration.
- Boot volumes encryption with customer managed keys from OCI Vault service.
- In-transit encryption for boot volumes and attached block volumes.
- Data in-use encryption for platform images ([Confidential computing](https://docs.oracle.com/en-us/iaas/Content/Compute/References/confidential_compute.htm)).
- [Shielded Compute instances](https://docs.oracle.com/en-us/iaas/Content/Compute/References/shielded-instances.htm).
- Boot volumes backup with Oracle managed policies.

### Block Volumes
- CIS profile level drives data at rest encryption configuration.
- Data at rest encryption with customer managed keys from OCI Vault service.
- In-transit encryption for attached Compute instances.
- Cross-region replication for strong cyber resilience posture.
- Backups with Oracle managed policies.

### File Storage
- CIS profile level drives data at rest encryption configuration.
- Data at rest encryption with customer managed keys from OCI Vault service.
- Cross-region replication for strong cyber resilience posture.
- Backups with custom snapshot policies.

## <a name="requirements">Requirements</a>
### IAM Permissions

This module requires the following OCI IAM permissions in the compartments where instances, block volumes, and file systems are defined. 

For deploying Compute instances:
```
Allow group <GROUP-NAME> to manage instance-family in compartment <INSTANCE-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to read instance-agent-plugins in compartment <INSTANCE-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to read instance-images in compartment <IMAGE-COMPARTMENT-NAME> # if images are not in the same compartment as the instances themselves.
Allow group <GROUP-NAME> to read virtual-network-family in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to use subnets in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to use network-security-groups in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to use vnics in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to manage private-ips in compartment <NETWORK-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to read keys in compartment <ENCRYPTION-KEYS-COMPARTMENT-NAME>
Allow group <GROUP-NAME> to use key-delegate in compartment <ENCRYPTION-KEYS-COMPARTMENT-NAME>
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

### Terraform Version > 1.3.x

This module relies on [Terraform Optional Object Type Attributes feature](https://developer.hashicorp.com/terraform/language/expressions/type-constraints#optional-object-type-attributes), which has been promoted and no longer experimental in versions greater than 1.3.x. The feature shortens the amount of input values in complex object types, by having Terraform automatically inserting a default value for any missing optional attributes.

## <a name="functioning">Module Functioning</a>

The module defines two top level attributes used to manage instances and storage: 
- **instances_configuration**: for managing Compute instances.
- **storage_configuration**: for managing storage, including Block Volumes and File System Storage.

### <a name="compute">Compute</a>

Compute instances are managed using the **instances_configuration** object. It contains a set of attributes starting with the prefix **default_** and one attribute named **instances**. The **default_** attribute values are applied to all instances within **instances**, unless overriden at the instance level.

The *default_* attributes are the following:
- **default_compartment_id**: the default compartment for all instances. It can be overriden by *compartment_id* attribute in each instance. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **default_subnet_id**: the default subnet for all instances. It can be overriden by *subnet_id* attribute in each instance. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *network_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **default_ssh_public_key_path**: the default SSH public key path used to access all instances. It can be overriden by the *ssh_public_key* attribute in each instance.
- **default_kms_key_id**: the default encryption key for all instances. It can be overriden by *kms_key_id* attribute in each instance. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *kms_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **default_cis_level**: the default CIS OCI Benchmark profile level for all instances. Level "2" enforces usage of customer managed keys for boot volume encryption. Default is "1". It can be overriden by *cis_level* attribute in each instance.
- **default_defined_tags**: the default defined tags for all instances. It can be overriden by *defined_tags* attribute in each instance.
- **default_freeform_tags**: the default freeform tags for all instances. It can be overriden by *freeform_tags* attribute in each instance.

The instances themselves are defined within the **instances** attribute, In Terraform terms, it is a map of objects. where each object is referred by an identifying key. The supported attributes are listed below. For better usability, most attributes are grouped in logical blocks. They are properly indented in the list.
- **compartment_id**: the instance compartment. *default_compartment_id* is used if undefined. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **cis_level**: the CIS OCI Benchmark profile level to apply. *default_cis_level* is used if undefined.
- **shape**: the instance shape. See [Compute Shapes](https://docs.oracle.com/en-us/iaas/Content/Compute/References/computeshapes.htm) for OCI Compute shapes.
- **name**: the instance name.
- **platform_type**: the platform type. Assigning this attribute enables important platform security features in the Compute service. See [Enabling Platform Features](#platform-features) for more information. Valid values: "AMD_MILAN_BM", "AMD_MILAN_BM_GPU", "AMD_ROME_BM", "AMD_ROME_BM_GPU", "AMD_VM", "GENERIC_BM", "INTEL_ICELAKE_BM", "INTEL_SKYLAKE_BM", "INTEL_VM". By default, no platform features are enabled.
- **ssh_public_key_path**: the SSH public key path used to access the instance. *default_ssh_public_key_path* is used if undefined.
- **defined_tags**: the instance defined tags. *default_defined_tags* is used if undefined.
- **freeform_tags**: the instance freeform tags. *default_freeform_tags* is used if undefined.
- **image**: the instance base image. You must provider either the id or (name and publisher name). See [Obtaining OCI Platform Images Information](#platform-images) for how to get OCI Platform images and [Obtaining OCI Marketplace Images Information](#marketplace-images) for how to get OCI Marketplace images.
  - **id**: the image id for the instance. It takes precedence over name and publisher.
  - **name**: the image name to search for in OCI Marketplace. 
  - **publisher**: the image's publisher name.
- **placement**: instance placement settings.
  - **availability_domain**: the instance availability domain. Default is 1.
  - **fault_domain**: the instance fault domain. Default is 1.
- **boot_volume**: boot volume settings.
  - **type**: boot volume emulation type. Valid values: "PARAVIRTUALIZED", "SCSI", "ISCSI", "IDE", "VFIO". Default is "PARAVIRTUALIZED".
  - **firmware**: firmware used to boot the VM. Valid options: "BIOS" (compatible with both 32 bit and 64 bit operating systems that boot using MBR style bootloaders), "UEFI_64" (default for platform images).
  - **size**: boot volume size. Default is 50 (in GB, the minimum allowed by OCI).
  - **preserve_on_instance_deletion**: whether to preserve boot volume after deletion. Default is true.
  - **secure_boot**: prevents unauthorized boot loaders and operating systems from booting. Default is false. Only applicable if *platform_type* is set.
  - **measured_boot**: enhances boot security by taking and storing measurements of boot components, such as bootloaders, drivers, and operating systems. Bare metal instances do not support Measured Boot. Default is false. Only applicable if *platform_type* is set.
  - **trusted_platform_module**: used to securely store boot measurements. Default is false. Only applicable if *platform_type* is set.
  - **backup_policy**: the Oracle managed backup policy for the boot volume. Valid values: "gold", "silver", "bronze". Default is "bronze".
- **volumes_emulation_type**: emulation type for attached storage volumes. Valid values: "PARAVIRTUALIZED" (default), "SCSI", "ISCSI", "IDE", "VFIO". 
- **networking**: networking settings. 
  - **type**: emulation type for the physical network interface card (NIC). Valid values: "PARAVIRTUALIZED" (default), "VFIO" (SR-IOV networking), "E1000" (compatible with Linux e1000 driver).
  - **hostname**: the instance hostname.
  - **assign_public_ip**: whether to assign the instance a public IP. Default is false.
  - **subnet_id**: the subnet where the instance is created. *default_subnet_id* is used if undefined. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *network_dependency* variable. See [External Dependencies](#ext-dep) for details.
  - **network_security_groups**: list of network security groups the instance should be placed into. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *network_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **encryption**: encryption settings. See section [In Transit Encryption](#in-transit-encryption) for important information.
  - **kms_key_id**: the encryption key for boot volume encryption. *default_kms_key_id* is used if undefined. Required if *cis_level* or *default_cis_level* is "2".
  - **encrypt_in_transit_on_instance_create**: whether to enable in-transit encryption for the instance. Default is set by the underlying image. Applicable during instance **creation** time only. 
  - **encrypt_in_transit_on_instance_update**: whether to enable in-transit encryption for the instance. Default is set by the underlying image. Applicable during instance **update** time only. **Do not** set this attribute when initially provisioning the instance (use *encrypt_in_transit_on_instance_create* instead).
  - **encrypt_data_in_use**: whether the instance encrypts data in-use (in memory) while being processed. A.k.a confidential computing. Default is false. Only applicable if *platform_type* is set.
- **flex_shape_settings**: flex shape settings.
  - **memory**: the instance memory for Flex shapes. Default is 16 (in GB).
  - **ocpus**: the number of OCPUs for Flex shapes. Default is 1.

#### <a name="platform-features">Enabling Platform Features</a>
The module currently supports [Confidential computing](https://docs.oracle.com/en-us/iaas/Content/Compute/References/confidential_compute.htm) and [Shielded instances](https://docs.oracle.com/en-us/iaas/Content/Compute/References/shielded-instances.htm), which cannot be enabled at the same time.
- Confidential computing usage is controlled by *platform_type* and *encryption.encrypt_data_in_use* attributes. 
- Confidential computing is only available for the shapes listed in [Compute Shapes that Support Confidential Computing](https://docs.oracle.com/en-us/iaas/Content/Compute/References/confidential_compute.htm#confidential_compute__coco_supported_shapes).
- Shielded instances usage is controlled by *platform_type*, *boot_volume.secure_boot*, *boot_volume.measured_boot* and *boot_volume.trusted_platform_module* attributes. For supported VM shapes, *boot_volume.measured_boot* value is used to set both *boot_volume.secure_boot* and *boot_volume.trusted_platform_module* attributes. 
- Shielded instances are only available for the shapes and images listed in [Supported Shapes and Images](https://docs.oracle.com/en-us/iaas/Content/Compute/References/shielded-instances.htm#supported-shapes).

#### <a name="platform-images">Obtaining OCI Platform Images Information</a>
Helper module [platform-images](../platform-images/) aids in finding OCI Platform instances based on a search string. See [this example](../platform-images/examples/platform-images/) for finding images containing "Linux-8" in their names. It outputs information as shown below. Note it also outputs the compatible shapes for each image. 
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
Use *Id* value to seed *image.id* attribute. Use one of the *Compatible shapes* value to seed *shape* attribute.

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
Use the *Listing resource id* or *Image name and Publisher* to seed image.id or image.name and image.publisher attributes.

#### <a name="in-transit-encryption">In Transit Encryption</a>
As stated in https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/overview.htm#BlockVolumeEncryption:

*"In-transit encryption for boot and block volumes is only available for virtual machine (VM) instances launched from platform images, along with bare metal instances that use the following shapes: BM.Standard.E3.128, BM.Standard.E4.128, BM.DenseIO.E4.128. It is not supported on other bare metal instances. To confirm support for certain Linux-based custom images and for more information, contact Oracle support."*

Additionally, in-transit encryption is only available to paravirtualized volumes (boot and block volumes).

**Note:** platform images may not allow instances overriding the image configuration for in-transit encryption at instance launch time. In such cases, there are two options for enabling in-transit encryption:
1. set *encryption.encrypt_in_transit_on_instance_create* attribute to true. This attribute is only applicable when the instance is initially provisioned.
2. on any updates to the instance, set *encryption.encrypt_in_transit_on_instance_update* attribute to true. This attribute **must not** be set when the instance is initially provisioned.

### <a name="storage">Storage</a>

Storage is managed using the **storage_configuration** object. It contains a set of attributes starting with the prefix **default_** and two attribute named **block_volumes** and **file_storage**. The **default_** attribute values are applied to all storage units within **block_volumes** and **file_storage**, unless overriden at the storage unit level.

The *default_* attributes are the following:
- **default_compartment_id**: the default compartment for all storage units. It can be overriden by *compartment_id* attribute in each unit. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **default_subnet_id**: the default subnet for all file system mount targets. It can be overriden by *subnet_id* attribute in each mount target. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *network_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **default_kms_key_id**: the default encryption key for all storage units. It can be overriden by *kms_key_id* attribute in each unit. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *kms_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **default_cis_level**: the default CIS OCI Benchmark profile level for all storage units. Level "2" enforces usage of customer managed keys for storage encryption. Default is "1". It can be overriden by *cis_level* attribute in each unit.
- **default_defined_tags**: the default defined tags for all storage units. It can be overriden by *defined_tags* attribute in each unit.
- **default_freeform_tags**: the default freeform tags for all storage units. It can be overriden by *freeform_tags* attribute in each unit.

#### <a name="block-volumes">Block Volumes</a>
Block volumes are defined using the **block_volumes** attribute. In Terraform terms, it is a map of objects, where each object is referred by an identifying key. The following attributes are supported:
- **compartment_id**: the volume compartment. *default_compartment_id* is used if undefined. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **cis_level**: the CIS OCI Benchmark profile level to apply. *default_cis_level* is used if undefined.
- **display_name**: the volume display name.
- **availability_domain**: the volume availability domain. Default is 1.
- **volume_size**: the volume size. Default is 50 (GB).
- **vpus_per_gb**: the number of VPUs per GB of volume. Values are 0(LOW), 10(BALANCE), 20(HIGH), 30-120(ULTRA HIGH). Default is 0.
- **defined_tags**: the volume defined tags. *default_defined_tags* is used if undefined.
- **freeform_tags**: the volume freeform tags. *default_freeform_tags* is used if undefined.
- **attach_to_instance**: settings for block volume attachment. Note that the module does **not** mount the block volume in the instance. For instructions how to mount block volumes, please section [Mounting Block Volumes](#mounting-block-volumes).
  - **instance_id**: the instance that the volume attaches to. It must be one of the identifying keys in the *instances* map or in the *instances_dependency* variable. See [External Dependencies](#ext-dep) for details.
  - **device_name**: the device name where to mount the block volume. It must be one of the *disk_mappings* value in the *instances* map or in the *instances_dependency* object.
  - **attachment_type**: the block volume attachment type. Valid values: "PARAVIRTUALIZED" (default), "ISCSI".
- **encryption**: encryption settings
  - **kms_key_id**: the encryption key for volume encryption. *default_kms_key_id* is used if undefined. Required if *cis_level* or *default_cis_level* is "2". This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *kms_dependency* variable. See [External Dependencies](#ext-dep) for details.
  - **encrypt_in_transit**: whether traffic encryption should be enabled for the volume. It only works if the device emulation type is paravirtualized.
- **replication**: replication settings
  - **availability_domain**: the availability domain (AD) to replicate the volume. The AD is picked from the region set by the module client to *block_volumes_replication_region* provider alias. Check [here](./examples/storage-only/) for an example with cross-region replication.
- **backup_policy**: the Oracle managed backup policy for the volume. Valid values: "gold", "silver", "bronze". Default is "bronze".

##### <a name="mounting-block-volumes">Mounting Block Volumes</a>
As stated in https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/attachingavolume.htm:

*"On Linux-based instances, if you want to automatically mount volumes when the instance starts, you need to set some specific options in the /etc/fstab file, or the instance might fail to start. This applies to both iSCSI and paravirtualized attachment types. For volumes that use consistent device paths, see [fstab Options for Block Volumes Using Consistent Device Paths](https://docs.oracle.com/en-us/iaas/Content/Block/References/fstaboptionsconsistentdevicepaths.htm#fstab_Options_for_Block_Volumes_Using_Consistent_Device_Paths). For all other volumes, see [Traditional fstab Options](https://docs.oracle.com/en-us/iaas/Content/Block/References/fstaboptions.htm#Traditional_fstab_Options)."*

#### <a name="file-storage">File Storage</a>
The **file_storage** attribute defines the file systems, mount targets and snapshot policies for OCI File Storage service. The attribute **default_subnet_id** applies to all mount targets, unless overriden by **subnet_id** attribute in each mount target. Attribute **subnet_id** is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *network_dependency* variable. See [External Dependencies](#ext-dep) for details.

##### <a name="file-systems">File Systems</a>
File systems are defined using the attribute **file_systems**. In Terraform terms, it is a map of objects, where each object is referred by an identifying key. The following attributes are supported:
- **compartment_id**: the file system compartment. *storage_configuration*'s *default_compartment_id* is used if undefined. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **cis_level**: the CIS OCI Benchmark profile level to apply. *storage_configuration*'s *default_cis_level* is used if undefined.
- **file_system_name**: the file_system name.
- **availability_domain**: the file system availability domain. 
- **kms_key_id** : the encryption key for file system encryption. *storage_configuration*'s *default_kms_key_id* is used if undefined. Required if *cis_level* or *default_cis_level* is "2". This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *kms_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **replication**: replication settings. To set the file system as a replication target, set *is_target* to true. To set the file system as a replication source, provide the replication file system target in *file_system_target_id*. A file system cannot be replication source and target at the same time.
  - **is_target**: whether the file system is a replication target. If this is true, then *file_system_target_id* must not be set. Default is false.
  - **file_system_target_id**: the file system remote replication target for this file system. It must be an existing unexported file system, in the same or in a different region than this file system. If this is set, then *is_target* must be false. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *file_systems_dependency* variable. See [External Dependencies](#ext-dep) for details.
  - **interval_in_minutes**: time interval (in minutes) between replication snapshots. Default is 60 minutes.
- **snapshot_policy_id**: the snapshot policy identifying key in the *snapshots_policy* map. Default snapshot policies are associated with file systems without a snapshot policy.
- **defined_tags**: file system defined_tags. *storage_configuration*'s *default_defined_tags* is used if undefined.
- **freeform_tags**: file system freeform_tags. *storage_configuration*'s *default_freeform_tags* is used if undefined.

##### <a name="mount-targets">Mount Targets</a>
Mount targets are defined using the attribute **mount_targets**. In Terraform terms, it is a map of objects, where each object is referred by an identifying key. The following attributes are supported:
- **compartment_id**: the mount target compartment. *storage_configuration*'s *default_compartment_id* is used if undefined. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **mount_target_name**: the mount target and export set name.
- **availability_domain**: the mount target availability domain.  
- **subnet_id**: the mount target subnet. *file_storage*'s *default_subnet_id* is used if undefined. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *network_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **exports**: export settings. In Terraform terms, it is a map of objects, where each object is referred by an identifying key. The following attributes are supported:
  - **path**: export path.
  - **file_system_key**: the file system identifying key this mount target applies.
  - **options**: list of export options.
    - **source**: the source IP address or CIDR range allowed to access the mount target.
    - **access**: type of access grants. Valid values (case sensitive): "READ_WRITE", "READ_ONLY". Default is "READ_ONLY".
    - **identity**: UID and GID remapped to. Valid values(case sensitive): ALL, ROOT, NONE. Default is "NONE".
    - **use_port**: Whether file system access is only allowed from a privileged source port. Default is true.

##### <a name="snapshot-policies">Snapshot Policies</a>
Snapshot policies are defined using the attribute **snapshot_policies**. In Terraform terms, it is a map of objects, where each object is referred by an identifying key. The following attributes are supported:
- **name**: the snapshot policy name.
- **compartment_id**: the snapshot policy compartment. *storage_configuration*'s *default_compartment_id* is used if undefined. This attribute is overloaded. It can be assigned either a literal OCID or a reference (a key) to an OCID in *compartments_dependency* variable. See [External Dependencies](#ext-dep) for details.
- **availability_domain**: the snapshot policy availability domain.
- **prefix**: the prefix to apply to all snapshots created by this policy.
- **schedules** a list of schedules to run the policy. A maximum of 10 schedules can be associated with a policy.
  - **period**: valid values: "DAILY", "WEEKLY", "MONTHLY", "YEARLY".
  - **prefix**: a name prefix to be applied to snapshots created by this schedule.
  - **time_zone**: the schedule time zone. Default is "UTC".
  - **hour_of_day**: the hour of the day to create a "DAILY", "WEEKLY", "MONTHLY", or "YEARLY" snapshot. If not set, a value will be chosen at creation time. Default is 23.
  - **day_of_week**: the day of the week to create a scheduled snapshot. Used for "WEEKLY" snapshot schedules. 
  - **day_of_month**: the day of the month to create a scheduled snapshot. If the day does not exist for the month, snapshot creation will be skipped. Used for "MONTHLY" and "YEARLY" snapshot schedules. 
  - **month**: the month to create a scheduled snapshot. Used only for "YEARLY" snapshot schedules. 
  - **retention_in_seconds**: the number of seconds to retain snapshots created with this schedule. Snapshot expiration time is not set if this value is empty. 
  - **start_time**: the starting point used to begin the scheduling of the snapshots based upon recurrence string in RFC 3339 timestamp format. If no value is provided, the value is set to the time when the schedule is created. 
- **defined_tags**: snapshot policy defined tags. *storage_configuration*'s *default_defined_tags* is used if undefined.
- **freeform_tags**: snapshot policy freeform tags. *storage_configuration*'s *default_freeform_tags* is used if undefined.

As mentioned, default snapshot policies are created for file systems that do not have a snapshot policy. The default snapshot policies are defined with a single schedule, set to run weekly at 23:00 UTC on sundays.

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
  - an *id* attribute with the subnet OCID.
  - an *id* attribute with the network security group OCID.

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
- **kms_dependency**: A map of objects containing the externally managed encryption keys this module may depend on. All map objects must have the same type and must contain at least an *id* attribute with the encryption key OCID.

Example:
```
{
	"APP-KEY": {
		"id": "ocid1.key.oc1.iad.ejsppeqvaafyi.abuwcl...yna"
	}
}
```
- **instances_dependency**: A map of objects containing the externally managed instances this module may depend on. All map objects must have the same type and should contain at least the following attributes:
  - an *id* attribute with the instance OCID.
  - a *is_pv_encryption_in_transit_enabled* attribute informing whether the instance supports in-transit encryption.

Example:
```
{
	"INSTANCE-2": {
		"id": "ocid1.instance.oc1.iad.anuwc...ftq",
        "remote_data_volume_type": "PARAVIRTUALIZED",
        "is_pv_encryption_in_transit_enabled" : false
	}
}
```
- **file_system_dependency**: A map of objects containing the externally managed file systems this module may depend on. All map objects must have the same type and must contain at least an *id* attribute with the file system OCID.

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
2. Terraform does not destroy replicated Block volumes. It is first necessary to disable replication (you can use OCI Console) before running *terraform destroy*.

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
1. set *encryption.encrypt_in_transit_on_instance_create* attribute to true. This attribute is only applicable when the instance is initially provisioned.
2. on any updates to the instance, set *encryption.encrypt_in_transit_on_instance_update* attribute to true. This attribute **must not** be set when the instance is initially provisioned.

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
