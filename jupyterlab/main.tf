terraform {
  required_version = ">= 1.0"

  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 0.17"
    }
  }
}

# Add required variables for your modules and remove any unneeded variables
variable "agent_id" {
  type        = string
  description = "The ID of a Coder agent."
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

resource "coder_script" "jupyterlab" {
  agent_id     = var.agent_id
  display_name = "jupyterlab"
  icon         = "/icon/jupyter.svg"
  script = templatefile("${path.module}/run.sh", {
    LOG_PATH : var.log_path,
    PORT : var.port,
    SUBDOMAIN : var.subdomain,
    SERVER_BASE_PATH : var.subdomain ? "" : format("/@%s/%s.%s/apps/jupyterlab", data.coder_workspace_owner.me.name, data.coder_workspace.me.name, var.agent_name),
  })
  run_on_start = true
}

resource "coder_app" "jupyterlab" {
  agent_id     = var.agent_id
  slug         = "jupyterlab"
  display_name = "JupyterLab"
  url          = "http://localhost:${var.port}"
  icon         = "/icon/jupyter.svg"
  subdomain    = var.subdomain
  share        = var.share
  order        = var.order
}
