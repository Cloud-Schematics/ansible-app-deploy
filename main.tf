
provider "ibm" {
  # ibmcloud_api_key = var.ibmcloud_api_key
  version = ">= 1.5.3"
}

data "ibm_schematics_workspace" "vpc" {
  workspace_id = var.workspace_id
}

data "ibm_schematics_output" "vpc" {
  workspace_id = var.workspace_id
  template_id  = "${data.ibm_schematics_workspace.vpc.template_id.0}"
}

data "ibm_schematics_state" "vpc" {
  workspace_id = var.workspace_id
  template_id  = "${data.ibm_schematics_workspace.vpc.template_id.0}"
}


resource "local_file" "terraform_source_state" {
  filename          = "${path.module}/ansible-data/schematics.tfstate"
  sensitive_content = data.ibm_schematics_state.vpc.state_store_json

}

output "app_dns_hostname" {
  value = data.ibm_schematics_output.vpc.output_values["app_dns_hostname"]

}

resource "null_resource" "ansible" {
  connection {
    bastion_host = data.ibm_schematics_output.vpc.output_values["bastion_host_ip_address"]
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
        file_path = "${path.module}/ansible-data/playbooks/site.yml"

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

variable "ssh_private_key" {
}


# variable "ibmcloud_api_key" {
#   description = "IBM Cloud API key when run standalone"
# }

variable "workspace_id" {
  description = "Id of the source Schematics Workspace for target VSIs"
  default     = "ssh_bastion-host-0353ce37-3748-4c"
}



