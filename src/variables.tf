variable "name" {
  description = "Namespace name"
}

variable "vault_path" {
  description = "Like secret/team_name/cluster_name/namespace"
  default     = ""
}

variable "gitlab_registry_dockercfg" {
  description = "Gitlab registry dockercfg"
}

variable "cpu_request" {
  description = "CPU Request"
  default     = "400m"
}

variable "memory_request" {
  description = "Memory Request"
  default     = "500M"
}

variable "cpu_limit" {
  description = "CPU Limit"
  default     = "800m"
}

variable "memory_limit" {
  description = "Memory Limit"
  default     = "1Gi"
}

variable "additional_k8s_vars" {
  type    = "map"
  default = {}
}

variable "k8s_sources_path" {
  description = "Path to k8s root directory, default is '$${path.root}/k8s/'"
  default = ""
}

variable "run_template_dir" {
  default = true
}

variable "deploy_user" {
  default = ""
}

variable "should_create_deploy_user" {
  default = 1
}

variable "labels" {
  type = "map"
  default = {}
}

locals {
  k8s_sources_templates_path = "${var.k8s_sources_path != "" ? var.k8s_sources_path : "${path.root}/k8s/"}templates/${var.name}"
  k8s_sources_generated_path = "${var.k8s_sources_path != "" ? var.k8s_sources_path : "${path.root}/k8s/"}generated/${var.name}"
}
