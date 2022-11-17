
terraform {
  required_version = ">= 1.0.0, < 2.0.0"
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "~> 1.33.0"
    }
  }
}

data "ibm_schematics_workspace" "vpc" {
  workspace_id = var.workspace_id
}

# output "schematics_workspace" {
#   value = data.ibm_schematics_workspace.vpc
# }


data "ibm_schematics_output" "vpc" {
  workspace_id = var.workspace_id
  # template_id  = "c7ed00f0-782d-4d"
  template_id = data.ibm_schematics_workspace.vpc.runtime_data[0].id
}

output "schematics_outputs" {
  value = data.ibm_schematics_output.vpc
}




data "ibm_schematics_state" "vpc" {
  workspace_id = var.workspace_id
  template_id  = data.ibm_schematics_workspace.vpc.runtime_data[0].id
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
  description = "ID of the VPC Workspace containing VSIs, e.g. us-south.workspace.<VPC_workspace>.123456790"
}



