# Copyright (c) 2023 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

#--------------------------------------------------------------------------------------------------------------------------------------
# 1. Rename this file to <project-name>.auto.tfvars, where <project-name> is a name of your choice.
# 2. Provide values for "Tenancy Connectivity Variables".
# 3. Replace <REPLACE-BY-COMPARTMENT-OCID>, <REPLACE-BY-METRIC-COMPARTMENT-OCID>, <REPLACE-BY-TOPIC-OCID> placeholders 
#    by appropriate compartment and topic OCIDs.
# 4. Replace email.address@example.com by actual email addresses.
#--------------------------------------------------------------------------------------------------------------------------------------

#---------------------------------------
# Tenancy Connectivity Variables
#---------------------------------------

tenancy_ocid         = "ocid1.tenancy.oc1..aaaaaaaaixl3xlr4kr6h3yax2zbijclgim5q2l2pv2qmfithywqhw4tgbvuq" #ateamocidev
user_ocid            = "ocid1.user.oc1..aaaaaaaalxqallveu54dikz2yvwztfa6aaonjyn7mopu2oyy4hqjjbbdukca" #andre.correa@oracle.com local
fingerprint          = "ec:5e:dd:5a:4c:75:b7:00:e5:ee:44:f9:05:47:4f:fe" #tenant admin
private_key_path     = "../../private_key_ateamocidev.pem"
private_key_password = ""
region               = "us-ashburn-1"

block_volumes_replication_region = "sa-saopaulo-1"

#tenancy_ocid         = "ocid1.tenancy.oc1..aaaaaaaa3pbmdv223ttwv4wjvmn4jvcw4gxc3skym74itutnnoisg5zrbnuq" 
#user_ocid            = "ocid1.user.oc1..aaaaaaaaw3evukcrc5a72revdr6gj4bfay6ilsyuwu75fmbx3t6xw2qxa5pa" #stack-compute-admin-user
#fingerprint          = "ec:12:aa:28:1f:47:99:c2:1d:86:74:f6:d7:b3:c8:cf"  
#private_key_path     = "../stack-compute-admin-user_cislzground.pem"
#private_key_password = ""  
#region               = "us-ashburn-1" 

#user_ocid="ocid1.user.oc1..aaaaaaaajhy4l62q5y2thovx4em2ttq3c35ff3hs3czsp6c7p45exoczufia"
#fingerprint="47:dd:e6:92:c8:06:90:84:03:0f:94:30:8a:9d:48:2a"
#private_key_path="../private_key_cislzground.pem"

#---------------------------------------
# Input variable
#---------------------------------------

instances_configuration = {
  default_compartment_id = "APP-CMP" # obtained from oci_compartments_dependency.
  default_subnet_id = "APP-SUBNET" # obtained from oci_network_dependency.
  default_kms_key_id = "APP-KEY" # obtained from oci_kms_dependency.
  default_ssh_public_key_path = "~/.ssh/id_rsa.pub"
  instances = {
    INSTANCE-1 = {
      shape = "VM.Standard.E4.Flex"
      name  = "Oracle Linux 7 STIG Instance 1 (external-dependencies)"
      placement = {
        availability_domain = 1
        fault_domain = 1
      }
      boot_volume = {
        size = 120
        preserve_on_instance_deletion = false
      }
      device_mounting = {
        disk_mappings = "/u01:/dev/oracleoci/oraclevdb"
        emulation_type = "paravirtualized"
      }
      encryption = {
        encrypt_in_transit_at_instance_creation = false
      }
      networking = {
        #type = "VFIO"
        hostname  = "oracle-linux-7-stig-instance-1-ext-dep"
        assign_public_ip = false
        network_security_groups = ["APP-NSG"] # obtained from oci_network_dependency.
      }
      image = {
        name = "Oracle Linux 7 STIG"
        publisher_name = "Oracle Linux"
      }
    }
  }
}

storage_configuration = {
  default_compartment_id = "APP-CMP" # obtained from oci_compartments_dependency.
  block_volumes = {
    BV-1 = {
      display_name = "block-volume-1"
      availability_domain = 1   
      attach_to_instance = { 
        instance_id = "INSTANCE-1" # obtained from local instances map.     
        device_name  = "/dev/oracleoci/oraclevdb"
      }
      encryption = {
        encrypt_in_transit = false
      }
      backup_policy = "bronze"
      replication = {
        availability_domain = 1
      }
    }
    BV-2 = {
      display_name = "block-volume-2"
      availability_domain = 1   
      attach_to_instance = { 
        instance_id = "INSTANCE-2" # obtained from oci_compute_dependency.      
        device_name  = "/dev/oracleoci/oraclevdb"
      }
      encryption = {
        kms_key_id = "APP-KEY" # obtained from oci_kms_dependency.
        encrypt_in_transit = false
      }
      backup_policy = "gold"
      replication = {
        availability_domain = 1
      }
    }
  }
}

oci_compartments_dependency = {
  bucket = "terraform-shared-config-bucket"
  object = "compartments.json"
}

oci_network_dependency = {
  bucket = "terraform-shared-config-bucket"
  object = "networking.json"
}

oci_kms_dependency = {
  bucket = "terraform-shared-config-bucket"
  object = "keys.json"
}

oci_compute_dependency = {
  bucket = "terraform-shared-config-bucket"
  object = "instances.json"
}
