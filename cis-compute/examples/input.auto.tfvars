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

tenancy_ocid         = "ocid1.tenancy.oc1..aaaaaaaa3pbmdv223ttwv4wjvmn4jvcw4gxc3skym74itutnnoisg5zrbnuq" 
#user_ocid            = "ocid1.user.oc1..aaaaaaaaw3evukcrc5a72revdr6gj4bfay6ilsyuwu75fmbx3t6xw2qxa5pa" #stack-compute-admin-user
#fingerprint          = "ec:12:aa:28:1f:47:99:c2:1d:86:74:f6:d7:b3:c8:cf"  
#private_key_path     = "../stack-compute-admin-user_cislzground.pem"
private_key_password = ""  
region               = "us-ashburn-1" 

user_ocid="ocid1.user.oc1..aaaaaaaajhy4l62q5y2thovx4em2ttq3c35ff3hs3czsp6c7p45exoczufia"
fingerprint="47:dd:e6:92:c8:06:90:84:03:0f:94:30:8a:9d:48:2a"
private_key_path="../private_key_cislzground.pem"

#---------------------------------------
# Input variable
#---------------------------------------

instances_configuration = {
  default_compartment_id    = "ocid1.compartment.oc1..aaaaaaaa7gcnlsdfsrcdfft3hta66l7giznjh7ky6gagoxh26j5rm6jyacnq" #cis-landing-zone/cislz-appdev-cmp
  default_subnet_id         = "ocid1.subnet.oc1.iad.aaaaaaaady5hxhf72ycl3yuvqxxay7h5ifyj6aa6alxibgghq46lvj7nwzeq" #cislz-0-vcn/cislz-0-app-subnet
  default_kms_key_id        = null
  default_ssh_public_key_path = "~/.ssh/id_rsa.pub"
  instances = {
    INSTANCE-1 = {
      shape     = "VM.Standard2.4"
      hostname  = "oracle-linux-7-stig-instance-1"
      placement = {
        availability_domain = 1
        fault_domain = 2
      }
      boot_volume = {
        size = 120
        preserve_on_instance_deletion = false
      }
      attached_storage = {
        device_disk_mappings = "/u01:/dev/oracleoci/oraclevdb /u02:/dev/oracleoci/oraclevdc /u03:/dev/oracleoci/oraclevdd /u04:/dev/oracleoci/oraclevde"
        attachment_type = "paravirtualized"
      }
      encryption = {
        encrypt_in_transit = false
      }
      networking = {
        assign_public_ip = false
        subnet_id = null
        network_security_groups = null
      }
      image = {
        name = "Oracle Linux 7 STIG"
        publisher_name = "Oracle Linux"
      }
    }
  }
}

storage_configuration = {
  default_compartment_id = "ocid1.compartment.oc1..aaaaaaaa7gcnlsdfsrcdfft3hta66l7giznjh7ky6gagoxh26j5rm6jyacnq" #cis-landing-zone/cislz-appdev-cmp
  default_subnet_id = "ocid1.subnet.oc1.iad.aaaaaaaady5hxhf72ycl3yuvqxxay7h5ifyj6aa6alxibgghq46lvj7nwzeq"
  block_volumes = {
    BV-1 = {
      display_name        = "block-volume-1"
      #availability_domain = 1   
      #volume_size        = 50
      #vpus_per_gb        = 0           
      attach_to_instance = { 
        instance_key = "INSTANCE-1"      
        device_name  = "/dev/oracleoci/oraclevdb"
      }
      encryption = {
        encrypt_in_transit = false
      }
      backup_policy = "bronze"
      replication_availability_domain = 2
    }
    BV-2 = {
      display_name        = "block-volume-2"
      #availability_domain = 1   
      #volume_size         = 50
      #vpus_per_gb         = 0           
      attach_to_instance = { 
        instance_key = "INSTANCE-1"      
        device_name  = "/dev/oracleoci/oraclevdc"
      }
      encryption = {
        encrypt_in_transit = false
      }
      backup_policy = "silver"
      replication_availability_domain = 3
    }
  }

   file_storage = {
    file_system = {
      FS-1 = {
        file_system_name = "file-system-1"
      }
    }
    mount_target = {
      MT-1 = {
        mount_target_name = "mount-target-1"
        exports = {
          EXP-1 = {
            path = "/andre"
            file_system_key = "FS-1"
            options = [
              {source = "0.0.0.0/0", access = "READ_ONLY", identity = "NONE", use_port = true}, 
              {source = "160.34.115.85/32", access = "READ_WRITE", identity = "ROOT", use_port = true}
            ]
          }
        }
      }
    }
    /* export = {
      EXP-1 = {
        filesystem_key = "FS-1"
        mount_target_key = "MT-1"
        path = "/andre"
      }
    } */
  } 
}


