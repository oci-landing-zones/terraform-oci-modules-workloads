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

storage_configuration = {
  default_compartment_id = "ocid1.compartment.oc1..aaaaaaaasmzo3tz65cnhnkyi3pnj77q7jftby2uwiqauuhbvppz7edqn67xq" #cis_landing_zone/cislztf-appdev-cmp
  default_subnet_id = "ocid1.subnet.oc1.iad.aaaaaaaax7tes37ulxp62pk6w5iigt2z5hc4rqdtui676espctwrhrexge7a" #cis_landing_zone/cislztf-network-cmp/vcn1/vcn1-app-subnet
  block_volumes = {
    BV-1 = {
      display_name = "block-volume-1"
      availability_domain = 1   
      encryption = {
        encrypt_in_transit = false
      }
      replication = {
        availability_domain = 1
      }
      backup_policy = "bronze"  
    }
  }

   file_storage = {
    file_systems = {
      FS-1 = {
        file_system_name = "file-system-1"
        availability_domain = 1
        replication = {
          file_system_target_id = "ocid1.filesystem.oc1.sa_saopaulo_1.aaaaaaaaaad7wft5m5zhkllqojxwiottmewxgylpobqxk3dpfuys2ylefuyqaaaa"
        }
        snapshot_policy_id = "SNAPSHOT-POLICY-1"
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
    snapshot_policies = {
      SNAPSHOT-POLICY-1 = {
        name = "snapshot-policy-1"
        schedules = [
          {period = "DAILY", prefix = "daily"}
        ]
      }
    }
  } 
}


