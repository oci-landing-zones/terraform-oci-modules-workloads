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

replication_region = "sa-saopaulo-1"

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
  default_compartment_id = "ocid1.compartment.oc1..aaaaaaaasmzo3tz65cnhnkyi3pnj77q7jftby2uwiqauuhbvppz7edqn67xq" #cis_landing_zone/cislztf-appdev-cmp
  default_subnet_id = "ocid1.subnet.oc1.iad.aaaaaaaax7tes37ulxp62pk6w5iigt2z5hc4rqdtui676espctwrhrexge7a" #cis_landing_zone/cislztf-network-cmp/vcn1/vcn1-app-subnet
  default_kms_key_id = null
  default_ssh_public_key_path = "~/.ssh/id_rsa.pub"
  instances = {
    INSTANCE-1 = {
      shape     = "VM.Standard2.4"
      name      = "Oracle Linux 7 STIG Instance 1"
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
        hostname  = "oracle-linux-7-stig-instance-1"
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
  default_compartment_id = "ocid1.compartment.oc1..aaaaaaaasmzo3tz65cnhnkyi3pnj77q7jftby2uwiqauuhbvppz7edqn67xq" #cis_landing_zone/cislztf-appdev-cmp
  default_subnet_id = "ocid1.subnet.oc1.iad.aaaaaaaax7tes37ulxp62pk6w5iigt2z5hc4rqdtui676espctwrhrexge7a" #cis_landing_zone/cislztf-network-cmp/vcn1/vcn1-app-subnet
  block_volumes = {
    BV-1 = {
      display_name = "block-volume-1"
      availability_domain = 1   
      attach_to_instance = { 
        instance_key = "INSTANCE-1"      
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
  }

   file_storage = {
    file_systems = {
      FS-1 = {
        file_system_name = "file-system-1"
        availability_domain = 1
      }
    }
    mount_targets = {
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
  } 
}


