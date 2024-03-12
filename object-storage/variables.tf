# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

variable object_storage_configuration {
  description = "Compute instances configuration attributes."
  type = object({
    default_compartment_id = optional(string)               
    default_namespace      = optional(string)
    default_kms_key_id     = optional(string)      
    default_cis_level      = optional(string)       
    default_defined_tags   = optional(map(string))
    default_freeform_tags  = optional(map(string))

    buckets = optional(map(object({
      cis_level           = optional(string)
      compartment_id      = optional(string) 
      name                = string 
      namespace           = optional(string)  
      access_type         = optional(string)  
      enable_auto_tiering = optional(bool)
      enable_object_events = optional(bool)
      enable_versioning    = optional(bool)
      kms_key_id          = optional(string)
      metadata            = optional(string)
      storage_tier        = optional(string)
      retention_rules     = optional(map(object({
        name = string
        duration_time_amount = number
        duration_time_unit   = string
        time_rule_locked     = optional(string)
      })))
      defined_tags  = optional(map(string))
      freeform_tags = optional(map(string))       
    })))

    objects = optional(map(object({
      cis_level = optional(string)
      bucket_id = string
      name      = string
      namespace = optional(string)
      source    = optional(string) # An absolute path to a file on the local system. It cannot be defined if content or source_uri_details is defined.
      source_uri_details = optional(object({ # Details of the source URI of the object in the cloud. It cannot be defined if content or source is defined. Note: To enable object copy, you must authorize the service to manage objects on your behalf.
        region      = string # The region of the source object.
        namespace   = string # The top-level namespace of the source object.
        bucket_name = string # The name of the bucket for the source object.
        object_name = string # The name of the source object.
        source_object_if_match_etag = optional(string) # The entity tag to match the source object.
        destination_object_if_match_etag = optional(string) # The entity tag to match the target object.
        destination_object_if_none_match_etag = optional(string) # The entity tag to not match the target object.
        source_version_id = optional(string) # The version id of the object to be restored.
      }))
      content = optional(object({ 
        content = string # The object to upload to the Object Storage. It cannot be defined if source or source_uri_details is defined.
        disposition = optional(string)
        encoding = optional(string)
        language = optional(string)
        length   = optional(string)
        md5      = optional(string)
        type     = optional(string)
      }))
      storage_tier = optional(string)
      metadata     = optional(string)
      kms_key_id   = optional(string)
      delete_all_object_versions = optional(bool)
      cache_control = optional(string)
    })))
  })  
}

variable "module_name" {
  description = "The module name."
  type        = string
  default     = "object-storage"
}

variable compartments_dependency {
  description = "A map of objects containing the externally managed compartments this module may depend on. All map objects must have the same type and must contain at least an 'id' attribute (representing the compartment OCID) of string type." 
  type = map(any)
  default = null
}

variable kms_dependency {
  description = "A map of objects containing the externally managed encryption keys this module may depend on. All map objects must have the same type and must contain at least an 'id' attribute (representing the key OCID) of string type." 
  type = map(any)
  default = null
}
