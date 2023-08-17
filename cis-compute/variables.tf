# Copyright (c) 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

variable "instances_configuration" {
  description = "Compute instances configuration attributes."
  type = object({
    default_compartment_id      = string,                # the default compartment where all resources are defined. It's overriden by the compartment_ocid attribute within each object.
    default_subnet_id           = optional(string),      # the default subnet where all Compute instances are defined. It's overriden by the subnet_id attribute within each Compute instance.
    default_ssh_public_key_path = optional(string),      # the default ssh public key path used to access the Compute instance. It's overriden by the ssh_public_key attribute within each Compute instance.
    default_kms_key_id          = optional(string),      # the default KMS key to assign as the master encryption key. It's overriden by the kms_key_id attribute within each object.
    default_cis_level           = optional(string)       # The CIS OCI Benchmark profile level. Level "1" is be practical and prudent. Level "2" is intended for environments where security is more critical than manageability and usability. Default is "1".
    default_defined_tags        = optional(map(string)), # the default defined tags. It's overriden by the defined_tags attribute within each object.
    default_freeform_tags       = optional(map(string)), # the default freeform tags. It's overriden by the frreform_tags attribute within each object.

    instances = map(object({ # the instances to manage in this configuration.
      cis_level            = optional(string)
      compartment_id       = optional(string)           # the compartment where the instance is created. default_compartment_ocid is used if this is not defined.
      shape                = string                     # the instance shape.
      hostname             = string                     # the instance hostname.
      image = object({ # the base image. You must provider either the id or (name and publisher name).
        id = optional(string) # the base image id for creating the instance. It takes precedence over name and publisher_name.
        name = optional(string) # the image name to search for in marketplace.
        publisher_name = optional(string) # the publisher name of the image name.
      })
      placement = optional(object({ # placement settings
        availability_domain  = optional(number,1) # the instance availability domain. Default is 1.
        fault_domain         = optional(number,1) # the instance fault domain. Default is 1.
      }))
      boot_volume = optional(object({ # boot volume settings
        size = optional(number,50) # boot volume size. Default is 50GB (minimum allowed by OCI).
        preserve_on_instance_deletion = optional(bool,true) # whether to preserve boot volume after deletion. Default is true.
      }))
      attached_storage = optional(object({ # storage settings. Attributes required by the cloud init script to attach block volumes.
        device_disk_mappings = optional(string) # device mappings to mount block volumes. If providing multiple mapping, separate the mappings with a blank space.
        attachment_type = optional(string) # the type of attachment for block volumes.
      }))
      networking = optional(object({ # networking settings
        assign_public_ip        = optional(bool,false)     # whether to assign the instance a public IP. Default is false.
        subnet_id               = optional(string)   # the subnet where the instance is created. default_subnet_id is used if this is not defined.
        network_security_groups = optional(list(string))  # list of network security groups the instance should be placed into.
      }))
      encryption = optional(object({ # encryption settings
        kms_key_id              = optional(string) # the KMS key to assign as the master encryption key. default_kms_key_id is used if this is not defined.
        encrypt_in_transit      = optional(bool,true)   # if the boot volume should encrypt in transit traffic. Default is true.
      }))
      flex_shape_settings = optional(object({ # flex shape settings
        memory = optional(number,16) # the instance memory for Flex shapes. Default is 16GB.
        ocpus  = optional(number,1)  # the instance ocpus number for Flex shapes. Default is 1.
      }))
      ssh_public_key = optional(string) # the SSH public key used to access the instance.
      defined_tags  = optional(map(string)) # instances defined_tags. default_defined_tags is used if this is not defined.
      freeform_tags = optional(map(string)) # instances freeform_tags. default_freeform_tags is used if this is not defined.
    }))
  })
}

variable "storage_configuration" {
  description = "Storage configuration attributes."
  type = object({

    default_compartment_id   = optional(string),      # the default compartment where all resources are defined. It's overriden by the compartment_id attribute within each object.
    default_kms_key_id       = optional(string),      # the default KMS key to assign as the master encryption key. It's overriden by the kms_key_id attribute within each object.
    default_subnet_id        = optional(string),      # the default subnet used for all file system mount targets. It's overriden by the subnet_id attribute within each mount_target object.
    default_cis_level        = optional(string)       # The CIS OCI Benchmark profile level. Level "1" is be practical and prudent. Level "2" is intended for environments where security is more critical than manageability and usability. Default is "1".
    default_defined_tags     = optional(map(string)), # the default defined tags. It's overriden by the defined_tags attribute within each object.
    default_freeform_tags    = optional(map(string)), # the default freeform tags. It's overriden by the frreform_tags attribute within each object.

    block_volumes = optional(map(object({    # the block volumes to manage in this configuration.
      cis_level           = optional(string)
      compartment_id      = optional(string) # the compartment where the block volume is created. default_compartment_id is used if this is not defined.
      display_name        = string           # the name of the block volume.
      availability_domain = optional(number,1)  # the availability domain where to create the block volume.     
      volume_size         = optional(number,50) # the size of the block volume.
      vpus_per_gb         = optional(number,0)  # the number of vpus per gb. Values are 0(LOW), 10(BALANCE), 20(HIGH), 30-120(ULTRA HIGH)
      attach_to_instance = optional(object({ # map to where to attach the block volume.
        instance_key = string                # the instance key the volume will be attached to.
        device_name  = optional(string)      # where to mount the block volume. Should be one of the values from device_disk_mappings in the instance_configuration.
      }))
      encryption = optional(object({ # encryption settings
        kms_key_id              = optional(string) # the KMS key to assign as the master encryption key. default_kms_key_id is used if this is not defined.
        encrypt_in_transit      = optional(bool,true)  # whether the block volume should encrypt traffic. Works only with paravirtualized attachment type. Default is true.
      }))
      backup_policy = optional(string)      # the Oracle managed backup policy. Valid values: "gold", "silver", "bronze". 
      replication_availability_domain = optional(number) # the availability domain (AD) to replicate the volume. The AD is picked from the region specified by 'replication_region' variable if defined. Otherwise picked the region specified by 'region' variable.
      defined_tags  = optional(map(string)) # block volume defined_tags. default_defined_tags is used if this is not defined.
      freeform_tags = optional(map(string)) # block volume freeform_tags. default_freeform_tags is used if this is not defined.
    }))),

    file_storage = optional(object({ # file storage settings.
      file_system = map(object({     # the file systems.
        cis_level           = optional(string)
        compartment_id      = optional(string) # the file system compartment. default_compartment_id is used if this is not defined.
        file_system_name    = string           # the file_system name.
        availability_domain = optional(number,1)  # the file system availability domain..   
        kms_key_id          = optional(string) # the KMS key to assign as the master encryption key. default_kms_key_id is used if this is not defined.
      }))
      mount_target = map(object({ # the mount targets.
        compartment_id      = optional(string) # the mount target compartment. default_compartment_id is used if this is not defined.
        mount_target_name   = string           # the mount target and export set name.
        availability_domain = optional(number,1) # the mount target availability domain.  
        subnet_id           = optional(string) # the mount target subnet. default_subnet_id is used if this is not defined.
        exports = optional(map(object({
          path = string
          file_system_key = string
          options = optional(list(object({ # optional export options.
            source   = string # the source IP or CIDR allowed to access the mount target.
            access   = optional(string, "READ_ONLY") # type of access grants. Valid values (case sensitive): READ_WRITE, READ_ONLY.
            identity = optional(string, "NONE") # UID and GID remapped to. Valid values(case sensitive): ALL, ROOT, NONE.
            use_port = optional(bool, true)   # If true, accessing the file system through this export must connect from a privileged source port.
          })))
        })))
      }))
    }))
  })
}

variable "enable_output" {
  description = "Whether Terraform should enable the module output."
  type        = bool
  default     = true
}

variable "module_name" {
  description = "The module name."
  type        = string
  default     = "cis-compute"
}

variable compartments_dependency {
  description = "A map of objects containing the externally managed compartments this module may depend on. All map objects must have the same type and must contain at least an 'id' attribute (representing the compartment OCID) of string type." 
  type = map(any)
  default = null
}

variable network_dependency {
  description = "A map of objects containing the externally managed network resources this module may depend on. All map objects must have the same type and must contain at least an 'id' attribute (representing the network resource OCID) of string type." 
  type = map(any)
  default = null
}

variable kms_dependency {
  description = "A map of objects containing the externally managed encryption keys this module may depend on. All map objects must have the same type and must contain at least an 'id' attribute (representing the key OCID) of string type." 
  type = map(any)
  default = null
}


