resource "null_resource" "ansible" {  
   provisioner "ansible" {
    plays {
      playbook {
        file_path = "${path.module}/ansible-data/ibmi.yml"

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
 
}
