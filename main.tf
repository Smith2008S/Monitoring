
# provider block required with Schematics to set VPC region
provider "ibm" {
  region = var.ibm_region
  #ibmcloud_api_key = var.ibmcloud_api_key
  generation = local.generation
  version    = "~> 1.4"
}

data "ibm_resource_group" "all_rg" {
  name = var.resource_group_name
}

locals {
  generation     = 2
  frontend_count = 1
}


##################################################################################################
#  Select CIDRs allowed to access bastion host  
#  When running under Schematics allowed ingress CIDRs are set to only allow access from Schematics  
#  for use with Remote-exec and Redhat Ansible
#  When running under Terraform local execution ingress is set to 0.0.0.0/0
#  Access CIDRs are overridden if user_bastion_ingress_cidr is set to anything other than "0.0.0.0/0" 
##################################################################################################











##################################################################################################
#  Config servers
##################################################################################################

output "datosdelworspace" {
  value = trim(lookup(data.external.env.result, "IC_ENV_TAGS", ""), "Schematics:")
}

data "ibm_schematics_workspace" "vpc" {
  workspace_id = trim(lookup(data.external.env.result, "IC_ENV_TAGS", ""), "Schematics:")
}

data "ibm_schematics_state" "vpc" {
  workspace_id = trim(lookup(data.external.env.result, "IC_ENV_TAGS", ""), "Schematics:")
  template_id  = "${data.ibm_schematics_workspace.vpc.template_id.0}"
#  depends_on = [module.frontend.security_group_id]
}

resource "time_sleep" "wait_360_seconds" {
  depends_on = [data.ibm_schematics_state.vpc]

  create_duration = "420s"
}

resource "local_file" "terraform_source_state" {
  filename          = "${path.module}/ansible-data/schematics.tfstate"
  sensitive_content = data.ibm_schematics_state.vpc.state_store_json
  depends_on = [time_sleep.wait_360_seconds]
}

resource "null_resource" "ansible" {
  connection {
    bastion_host = module.bastion.bastion_ip_addresses[0]
    host         = "0.0.0.0"
    #private_key = "${file("~/.ssh/ansible")}"
    private_key = var.ssh_private_key
  }

  triggers = {
    always_run = timestamp()
  }
  provisioner "ansible" {
    plays {
      playbook {
        file_path = "${path.module}/ansible-data/monitoring.yml"

	roles_path = ["${path.module}/ansible-data/roles"]
      }
      inventory_file = "${path.module}/terraform_inv.py"
      verbose        = true
    }
    ansible_ssh_settings {
      insecure_no_strict_host_key_checking = true
      connect_timeout_seconds              = 60
    }
  }
  depends_on = [local_file.terraform_source_state]
}
