terraform {
  required_version = ">= 1.0"

  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 0.17"
    }
  }
}

data "coder_workspace" "me" {}

data "coder_workspace_owner" "me" {}

# Add required variables for your modules and remove any unneeded variables
variable "agent_id" {
  type        = string
  description = "The ID of a Coder agent."
}

variable "agent_name" {
  type        = string
  description = "The name of the main deployment. (Used to build the subpath for coder_app.)"
  default     = ""
  validation {
    # If subdomain is false, then agent_name must be set.
    condition     = var.subdomain || var.agent_name != ""
    error_message = "The agent_name must be set."
  }
}

variable "log_path" {
  type        = string
  description = "The path to log jupyterlab to."
  default     = "/tmp/jupyterlab.log"
}

variable "port" {
  type        = number
  description = "The port to run jupyterlab on."
  default     = 19999
}

variable "share" {
  type    = string
  default = "owner"
  validation {
    condition     = var.share == "owner" || var.share == "authenticated" || var.share == "public"
    error_message = "Incorrect value. Please set either 'owner', 'authenticated', or 'public'."
  }
}

variable "order" {
  type        = number
  description = "The order determines the position of app in the UI presentation. The lowest order is shown first and apps with equal order are sorted by name (ascending order)."
  default     = null
}

variable "subdomain" {
  type        = bool
  description = <<-EOT
    Determines whether the app will be accessed via it's own subdomain or whether it will be accessed via a path on Coder.
    If wildcards have not been setup by the administrator then apps with "subdomain" set to true will not be accessible.
  EOT
  default     = true
}

locals {
  base_url = var.subdomain ? "/lab" : format("/@%s/%s.%s/apps/jupyterlab", data.coder_workspace_owner.me.name, data.coder_workspace.me.name, var.agent_name)  
}

resource "coder_script" "jupyterlab" {
  agent_id     = var.agent_id
  display_name = "jupyterlab"
  icon         = "/icon/jupyter.svg"
  script = templatefile("${path.module}/run.sh", {
    LOG_PATH : var.log_path,
    PORT : var.port,
    SUBDOMAIN : var.subdomain,
    SERVER_BASE_PATH : ${local.base_url},
  })
  run_on_start = true
}

resource "coder_app" "jupyterlab" {
  agent_id     = var.agent_id
  slug         = "jupyterlab"
  display_name = "JupyterLab"
  url          = "http://localhost:${var.port}${local.base_url}"
  icon         = "/icon/jupyter.svg"
  subdomain    = var.subdomain
  share        = var.share
  order        = var.order
}
