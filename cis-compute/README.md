# Oracle Cloud Infrastructure (OCI) Terraform CIS Compute Module

![Landing Zone logo](../landing_zone_300.png)

This module manages the creation and configuration of Compute instances and Block/File Storage in Oracle Cloud Infrastructure (OCI). The module automates the provisioning and configuration of Compute instances, handles App Catalog subscriptions, Block Volume and File Storage creation and attachment.

Check [module specification](./SPEC.md) for a full description of module requirements, supported variables, managed resources and outputs.

Check the [examples](./examples/) folder for actual module usage.

- [Requirements](#requirements)
- [Module Functioning](#functioning)
- [Known Issues](#issues)

## <a name="requirements">Requirements</a>
### IAM Permissions

This module requires the following OCI IAM permissions in the compartments where instances, block volumes, and file systems are defined. 

For deploying instances:
```
Allow group <group> to manage instance-family in compartment <instance-compartment-name>

```

For deploying block volumes:
```
Allow group <group> to manage volume-family in compartment <compartment-name>
```

For deploying file systems:
```
Allow group <group> to manage file-family in compartment <compartment-name>
```

## <a name="functioning">Module Functioning</a>

In this module, alarms are defined using the *alarms_configuration* object, that supports the following attributes:
- **default_compartment_ocid**: the default compartment for all resources managed by this module. It can be overriden by *compartment_ocid* attribute in each resource.
- **default_defined_tags**: the default defined tags that are applied to all resources managed by this module. It can be overriden by *defined_tags* attribute in each resource.
- **default_freeform_tags**: the default freeform tags that are applied to all resources managed by this module. It can be overriden by *freeform_tags* attribute in each resource.
- **instances**: define the instances. 
- **block_volumes**: define the block volumes. 
- **file_storage**: define the file storage resources.
- **file_system**: define the file system inside **file_storage**.
- **mount_target**: define the mount target inside **file_storage**.
- **export**: define the export inside **file_storage**.

**Note**: Each instance, block volume, file system, mount target and export are defined as an object whose key must be unique and must not be changed once defined. As a convention, use uppercase strings for the keys.

## Defining the Instances

- **availability_domain**: Use the *availability_domain* attribute to specify the Availability Domain where your instance will be hosted. Example: `availability_domain = 1`.
- **shape**: Use the *shape* attribute to specify the template that determines the number of CPUs, amount of memory, and other resources allocated to a newly created instance. Example: `shape = "VM.Standard2.4"`.
- **memory**: Use the *memory* attribute to specify the amount of memory for the instance when using a flexible shape. Example: `memory = 8`.
- **ocpus**: Use the *ocpus* attribute to specify the number of CPUs for the instance when using a flexible shape. Example: `ocpus = 1`.
- **hostname**: Use the *hostname* attribute to specify the name of the instance. Example: `hostname = "COMPUTE-INSTANCE"`.
- **boot_volume_size**: Use the *boot_volume_size* attribute to specify the size of the boot volume in GBs. Example: `boot_volume_size = 120`.
- **preserve_boot_volume**: Use the *preserve_boot_volume* attribute to choose whether the boot volume is preserved when the instance is terminated. Example: `preserve_boot_volume = true`.
- **assign_public_ip**: Use the *assign_public_ip* attribute to decide if a public IP should be assigned to the instance. Example: `assign_public_ip = true`.
- **kms_key_id**: Use the *kms_key_id* attribute to provide the OCID of the Key Management to be used for boot volume encryption. Example: `kms_key_id = "ocid1.key.oc1.eu-frankfurt-1..."`.
- **compartment_ocid**: Use the *compartment_ocid* attribute to specify the OCID of the compartment. If not specified, the instance is created in the *default_compartment_ocid*. Example: `compartment_ocid = null`.
- **subnet_ocid**: Use the *subnet_ocid* attribute to provide the OCID of the subnet within which the instance is to be created. Example: `subnet_ocid = "ocid1.subnet.oc1.eu-frankfurt-1..."`.
- **ssh_public_key**: Use the *ssh_public_key* attribute to specify the path of the SSH public key.If not specified, the instance will use the key from *default_ssh_public_key_path*. Example: `ssh_public_key = "~/.ssh/id_rsa.pub"`.
- **defined_tags**: Use the *defined_tags* attribute to specify defined tags for the instance.
- **freeform_tags**: Use the *freeform_tags* attribute to specify freeform tags for the instance. 
- **attached_storage**: Use the *attached_storage* attribute to specify additional storage attached to the instance. Example:
`
attached_storage = {
device_disk_mappings = "/u01:/dev/oracleoci/oraclevdb"
block_volume_attachment_type = "paravirtualized"
}
`
- **encrypt_in_transit**: Use the *encrypt_in_transit* attribute to enable encryption for data in transit. Example: `encrypt_in_transit = false`.
- **fault_domain**: Use the *fault_domain* attribute to specify the fault domain in which to launch the instance. Example: `fault_domain = 1`.
- **network_security_groups**: Use the *network_security_groups* attribute to specify the network security groups to associate with the instance. Example: `network_security_groups = [ocid...]`.
- **image_ocid**: Use the *image_ocid* attribute to specify the OCID of the image used to boot the instance. If not specified, you must provide the image details. Example: `image_ocid = ocid.image...`.
- **image**: Use the *image* attribute to provide details of the image used to boot the instance. Example:
`
image = {
  image_name     = "Image name"
  publisher_name = "Publisher"
}
`

## Defining the Block Volumes
- **compartment_ocid**: Use the *compartment_ocid* attribute to specify the OCID of the compartment. If not specified, the instance is created in the *default_compartment_ocid*. Example: `compartment_ocid = null`.
- **block_volume_name**: Use the *block_volume_name* attribute to specify the name of the block volume. Example: `block_volume_name = "BLOCK_VOLUME_1"`.
- **availability_domain**: Use the *availability_domain* attribute to specify the Availability Domain where your block volume will be hosted. Example: `availability_domain = 1`.
- **block_volume_size**: Use the *block_volume_size* attribute to specify the size of the block volume in GBs. Example: `block_volume_size = 50`.
- **vpus_per_gb**: Use the *vpus_per_gb* attribute to specify the number of Volume Performance Units (VPUs) that should be allocated per GB. Example: `vpus_per_gb = 10`.
- **encrypt_in_transit**: Use the *encrypt_in_transit* attribute to enable encryption for data in transit. Example: `encrypt_in_transit = false`.
- **kms_key_id**: Use the *kms_key_id* attribute to provide the OCID of the Key Management key to be used for volume encryption. Example: `kms_key_id = "ocid1.key..."`.
- **attach_to_instance**: Use the *attach_to_instance* attribute to specify details for attaching this volume to an instance. Example:
`
attach_to_instance = {
instance_key = "COMPUTE-INSTANCE"
device_name = "/dev/oracleoci/oraclevdb"
}
`
- **defined_tags**: Use the *defined_tags* attribute to specify defined tags for the block volume.
- **freeform_tags**: Use the *freeform_tags* attribute to specify freeform tags for the block volume. 

## Defining the File Storage

### Defining the file system
- **file_system_name**: Use the *file_system_name* attribute to specify the name of the file system. Example: `file_system_name = "FILE_SYSTEM_1"`.
- **availability_domain**: Use the *availability_domain* attribute to specify the Availability Domain where your file system will be hosted. Example: `availability_domain = 1`.
- **compartment_ocid**: Use the *compartment_ocid* attribute to specify the OCID of the compartment.  If not specified, the instance is created in the *default_compartment_ocid*. Example: `compartment_ocid = null`.
- **kms_key_id**: Use the *kms_key_id* attribute to provide the OCID of the Key Management to be used for encryption of the file system. If not specified, the service managed key for the account will be used. Example: `kms_key_id = null`.

### Defining the Mount Target
- **mount_target_name**: Use the *mount_target_name* attribute to specify the name of the mount target. Example: `mount_target_name = "MOUNT_TARGET_1"`.
- **availability_domain**: Use the *availability_domain* attribute to specify the Availability Domain where your mount target will be hosted. Example: `availability_domain = 1`.
- **compartment_ocid**: Use the *compartment_ocid* attribute to specify the OCID of the compartment.  If not specified, the instance is created in the *default_compartment_ocid*. Example: `compartment_ocid = null`.
- **subnet_ocid**: Use the *subnet_ocid* attribute to provide the OCID of the subnet in which the mount target is to be created. If not specified, the mount target is created in the *default_subnet_ocid*. Example: `subnet_ocid = null`.

### Defining the Export
- **filesystem_key**: Use the *filesystem_key* attribute to specify the key of the file system to be exported. Example: `filesystem_key = "FILE_SYSTEM_1"`.
- **mount_target_key**: Use the *mount_target_key* attribute to specify the key of the mount target for the export. Example: `mount_target_key = "MOUNT_TARGET_1"`.
- **path**: Use the *path* attribute to specify the path for the export. Example: `path = "/"`.
- **export_options**: Use the *export_options* attribute to specify a list of export options. This attribute is a list of maps, where each map describes a particular export option. Each map contains the following keys:
  - **source**: IP address or CIDR block from which to allow mounts. Example: `source = "1.1.1.1/24"`.
  - **access**: Type of access to grant to the file system. Valid options are: "READ_ONLY" or "READ_WRITE". Example: `access = "READ_WRITE"`.
  - **identity**: UID and GID remapped to. valid values(case sensitive): ALL, ROOT, NONE. Example: `identity = "ROOT"`.
  - **use_port**: A boolean value indicating whether to use the port or not. Example: `use_port = true`.

## <a name="issues">Known Issues</a>
None.
