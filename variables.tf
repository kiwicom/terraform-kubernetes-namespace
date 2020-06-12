variable "name" {
  description = "Namespace name"
}

variable "project_id" {
  description = "Google Cloud Platform project id"
}

variable "shared_vpc" {
  description = "Declares whether project is within shared VPC"
  default     = true
}

variable "gitlab_registry" {
  description = "Gitlab registry from where to pull images"
  default     = "registry.skypicker.com:5005"
}

variable "gitlab_rancher_username" {
  description = "Gitlab username of Rancher user"
  default     = "rancher"
}

variable "gitlab_rancher_password" {
  description = "Gitlab password of Rancher user"
}

variable "gcr_sa" {
  description = "Service account for accessing eu.gcr.io Docker registry (base64 encoded)"
  default     = ""
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
  type    = map(string)
  default = {}
}

variable "k8s_sources_path" {
  description = "Path to k8s root directory, default is '$$${path.root}/k8s/'"
  default     = ""
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
  type    = map(string)
  default = {}
}

variable "rancher2_project_id" {
  type = string
  default = ""
}

locals {
  k8s_sources_templates_path = "${var.k8s_sources_path != "" ? var.k8s_sources_path : "${path.root}/k8s/"}templates/${var.name}"
  k8s_sources_generated_path = "${var.k8s_sources_path != "" ? var.k8s_sources_path : "${path.root}/k8s/"}generated/${var.name}"
}
