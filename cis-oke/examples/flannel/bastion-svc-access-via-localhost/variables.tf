# Copyright (c) 2023 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

variable "tenancy_ocid" {}
variable "region" { description = "Your tenancy region" }
variable "user_ocid" { default = "" }
variable "fingerprint" { default = "" }
variable "private_key_path" { default = "" }
variable "private_key_password" { default = "" }

# variable "clusters_configuration" {
#   description = "Cluster configuration attributes."
#   type = object({
#     default_compartment_id         = optional(string),      # the default compartment where all resources are defined. It's overriden by the compartment_ocid attribute within each object.
#     default_img_kms_key_id         = optional(string)       # the default KMS key to assign as the master encryption key for images. It's overriden by the img_kms_key_id attribute within each object.
#     default_kube_secret_kms_key_id = optional(string)       # the default KMS key to assign as the master encryption key for kubernetes secrets. It's overriden by the kube_secret_kms_key_id attribute within each object.
#     default_cis_level              = optional(string, "1")  # The CIS OCI Benchmark profile level. Level "1" is be practical and prudent. Level "2" is intended for environments where security is more critical than manageability and usability. Default is "1".
#     default_defined_tags           = optional(map(string)), # the default defined tags. It's overriden by the defined_tags attribute within each object.
#     default_freeform_tags          = optional(map(string)), # the default freeform tags. It's overriden by the freeform_tags attribute within each object.
#     clusters = map(object({                                 # the clusters to manage in this configuration.
#       cis_level          = optional(string, "1")
#       compartment_id     = optional(string)            # the compartment where the cluster is created. default_compartment_ocid is used if this is not defined.
#       kubernetes_version = optional(string)            # the kubernetes version. If not specified the latest version will be selected.
#       name               = string                      # the cluster display name.
#       is_enhanced        = optional(bool, false)       # if the cluster is enhanced. It is designed to work only on Native CNI. Default is false.
#       cni_type           = optional(string, "flannel") # the CNI type of the cluster. Can be either "flannel" or "native". Default is "flannel".
#       defined_tags       = optional(map(string))       # clusters defined_tags. default_defined_tags is used if this is not defined.
#       freeform_tags      = optional(map(string))       # clusters freeform_tags. default_freeform_tags is used if this is not defined.
#       options = optional(object({                      # optional attributes for the cluster.
#         add_ons = optional(object({                    # configurable cluster addons.
#           dashboard_enabled = optional(bool, false)    # if the dashboard is enabled. Default to false.
#           tiller_enabled    = optional(bool, false)    # if the tiller is enabled. Default to false.
#         }))
#         admission_controller = optional(object({     # configurable cluster admission controllers. 
#           pod_policy_enabled = optional(bool, false) # if the pod policy is enabled. Default to false.
#         }))
#         kubernetes_network_config = optional(object({ # pods and services network configuration for kubernetes.
#           pods_cidr     = optional(string)            # the CIDR block for Kubernetes pods. Optional, defaults to 10.244.0.0/16.
#           services_cidr = optional(string)            # the CIDR block for Kubernetes services. Optional, defaults to 10.96.0.0/16.
#         }))
#         persistent_volume_config = optional(object({ # configuration to be applied to block volumes created by Kubernetes Persistent Volume Claims (PVC).
#           defined_tags  = optional(map(string))      # PVC defined_tags. default_defined_tags is used if this is not defined.
#           freeform_tags = optional(map(string))      # PVC freeform_tags. default_freeform_tags is used if this is not defined.
#         }))
#         service_lb_config = optional(object({   # configuration to be applied to load balancers created by Kubernetes services
#           defined_tags  = optional(map(string)) # LB defined_tags. default_defined_tags is used if this is not defined.
#           freeform_tags = optional(map(string)) # LB freeform_tags. default_freeform_tags is used if this is not defined.
#         }))
#       }))
#       networking = object({                         # cluster networking settings.
#         vcn_id             = string                 # the vcn where the cluster will be created.
#         public_endpoint    = optional(bool)         # if the api endpoint is public. default to false.
#         api_nsg_ids        = optional(list(string)) # the nsgs used by the api endpoint.
#         endpoint_subnet_id = string                 # the subnet for the api endpoint.
#         services_subnet_id = optional(list(string)) # the subnets for the services(Load Balancers).
#       })
#       encryption = optional(object({              # encryption settings
#         kube_secret_kms_key_id = optional(string) # # the KMS key to assign as the master encryption key for kube secrets. default_kube_secret_kms_key_id is used if this is not defined.
#       }))
#       image_signing = optional(object({
#         image_policy_enabled = optional(bool)   # whether the image verification policy is enabled. default to false.
#         img_kms_key_id       = optional(string) # the KMS key to assign as the master encryption key for images. default_img_kms_key_id is used if this is not defined.
#       }))
#     }))
#   })
#   default = null
# }

variable "clusters_configuration" {
  type = any
}

variable "workers_configuration" {
  type = any
}

variable "bastions_configuration" {
  type = any
}

variable "sessions_configuration" {
  type = any
}