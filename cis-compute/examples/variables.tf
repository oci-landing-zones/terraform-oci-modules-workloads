# Copyright (c) 2023 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

variable "tenancy_ocid" {}
variable "region" { description = "Your tenancy region" }
variable "user_ocid" { default = "" }
variable "fingerprint" { default = "" }
variable "private_key_path" { default = "" }
variable "private_key_password" { default = "" }

variable "instances_configuration" {
  description = "Compute instances configuration attributes."
  type = object({
    default_compartment_ocid    = string,                # the default compartment where all resources are defined. It's overriden by the compartment_ocid attribute within each object.
    default_defined_tags        = optional(map(string)), # the default defined tags. It's overriden by the defined_tags attribute within each object.
    default_freeform_tags       = optional(map(string)), # the default freeform tags. It's overriden by the frreform_tags attribute within each object.
    default_subnet_ocid         = string,                # the default subnet where all resources are defined. It's overriden by the subnet_ocid attribute within each object.
    default_ssh_public_key_path = string,                # the default ssh public key path used to access the instance. It's overriden by the ssh_public_key attribute within each object.
    default_kms_key_ocid        = string,                # the default kms key to assign as the master encryption key. It's overriden by the kms_key_id attribute within each object.
    default_cis_level           = optional(string)       # The CIS OCI Benchmark profile level. Level "1" is be practical and prudent. Level "2" is intended for environments where security is more critical than manageability and usability. Default is "1".

    instances = map(object({ # the instances to manage in this configuration.

      availability_domain  = number                     # the availability domain where to create the instance.
      shape                = string                     # the shape of the instance.
      hostname             = string                     # the hostname of the instance.
      boot_volume_size     = number                     # size of the boot volume.
      assign_public_ip     = optional(bool)             # if to assign a public ip. default is false.
      preserve_boot_volume = optional(bool)             # if to preserve boot volume after deletion. default is true
      compartment_ocid     = optional(string)           # the compartment where the instance is created. default_compartment_ocid is used if this is not defined.
      subnet_ocid          = optional(string)           # the subnet where the instance is created. default_subnet_ocid is used if this is not defined.
      ssh_public_key       = optional(string)           # the public ssh key used to access the instance
      defined_tags         = optional(map(string))      # instances defined_tags. default_defined_tags is used if this is not defined.
      freeform_tags        = optional(map(string))      # instances freeform_tags. default_freeform_tags is used if this is not defined.
      attached_storage = optional(object({              # map containing attributes required by the cloud init script to attach block volumes.
        device_disk_mappings         = optional(string) # mappings to places where to mount the block volumes
        block_volume_attachment_type = optional(string) # the type of attachment for block volumes.
      }))
      kms_key_id              = optional(string) # the  kms key to assign as the master encryption key. default_kms_key_ocid is used if this is not defined.
      encrypt_in_transit      = optional(bool)   # if the boot volume should have encrypt in transit.
      fault_domain            = number           # the fault domain where to create the instance.
      network_security_groups = list(string)     # list of network security groups ocids.
      image = optional(object({                  # search for an image on marketplace. image_ocid takes precedence.
        image_name     = string                  # the image name to search for in marketplace.
        publisher_name = string                  # the publisher name of that image.
      }))
      image_ocid = optional(string) # the image ocid to create the instance. takes precedence over image_name and publisher_name.
      memory     = optional(number) # the memory of the instance if the shape is Flex.
      ocpus      = optional(number) # the ocpus of the instance if the shape is Flex.
    }))
  })
}

variable "storage_configuration" {
  description = "Storage configuration attributes."
  type = object({

    default_compartment_ocid = optional(string),      # the default compartment where all resources are defined. It's overriden by the compartment_ocid attribute within each object.
    default_defined_tags     = optional(map(string)), # the default defined tags. It's overriden by the defined_tags attribute within each object.
    default_freeform_tags    = optional(map(string)), # the default freeform tags. It's overriden by the frreform_tags attribute within each object.
    default_kms_key_ocid     = optional(string),      # the default kms key to assign as the master encryption key. It's overriden by the kms_key_id attribute within each object.
    default_subnet_ocid      = optional(string),      # the default subnet used for file system mount target. It's overriden by the subnet_ocid attribute within each mount_targe object.

    block_volumes = optional(map(object({    # the block volumes to manage in this configuration.
      compartment_ocid    = optional(string) # the compartment where the block volume is created. default_compartment_ocid is used if this is not defined.
      block_volume_name   = string           # the name of the block volume.
      availability_domain = number           # the availability domain where to create the block volume.     
      block_volume_size   = number           # the size of the block volume.
      vpus_per_gb         = number           # the number of vpus per gb. Values are 0(LOW), 10(BALANCE), 20(HIGH), 30-120(ULTRA HIGH)
      encrypt_in_transit  = optional(bool)   # if the block volume should have encrypt in transit enabled. Works only with paravirtualized attachment type. Default to false.
      kms_key_id          = optional(string) # the  kms key to assign as the master encryption key. default_kms_key_ocid is used if this is not defined.
      attach_to_instance = optional(object({ # map to where to attach the block volume.
        instance_key = optional(string)      # the instance key the volume will be attached to.
        device_name  = optional(string)      # where to mount the block volume. Should be one of the values from device_disk_mappings in the instance_configuration.
      }))
      defined_tags  = optional(map(string)) # block volume defined_tags. default_defined_tags is used if this is not defined.
      freeform_tags = optional(map(string)) # block volume freeform_tags. default_freeform_tags is used if this is not defined.
    }))),

    file_storage = optional(object({           # the file storage to manage in this configuration.
      file_system = optional(map(object({      # the file system to manage in this configuration.
        file_system_name    = string           # the file_system name.
        availability_domain = number           # he availability domain where to create the file_system.   
        compartment_ocid    = optional(string) # the compartment where the file system is created. default_compartment_ocid is used if this is not defined.
        kms_key_id          = optional(string) # the  kms key to assign as the master encryption key. default_kms_key_ocid is used if this is not defined.
      })))
      mount_target = optional(map(object({     # the mount target of the file systems to manage in this configuration. It is used to create the export set as well.
        mount_target_name   = string           # the mount target and export set name.
        compartment_ocid    = optional(string) # the compartment where the mount target is created. default_compartment_ocid is used if this is not defined.
        availability_domain = number           # the availability domain where to create the mount target.  
        subnet_ocid         = optional(string) # the subnet used for the mount target. default_subnet_ocid is used if this is not defined.
      })))
      export = optional(map(object({            # the export of the file system to manage in this configuration.
        mount_target_key = string               # the key of the mount target. It is used as export_set.
        filesystem_key   = string               # the key if the file system.
        path             = string               # the path to export.
        export_options = optional(list(object({ # optional export options.
          source   = string                     # the ip or cidr where to apply the options.
          access   = string                     # type of access grants. valid values (case sensitive): READ_WRITE, READ_ONLY.
          identity = string                     # UID and GID remapped to. valid values(case sensitive): ALL, ROOT, NONE.
          use_port = bool                       # If true, accessing the file system through this export must connect from a privileged source port.
        })))
      })))
    }))
  })
}
