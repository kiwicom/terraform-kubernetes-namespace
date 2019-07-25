variable "name" {
  description = "Namespace name"
}

variable "vault_path" {
  description = "Like secret/team_name/cluster_name/namespace"
  default     = ""
}

variable "gitlab_rancher_password" {
  description = "Gitlab password of Rancher user"
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

locals {
  k8s_sources_templates_path = "${var.k8s_sources_path != "" ? var.k8s_sources_path : "${path.root}/k8s/"}templates/${var.name}"
  k8s_sources_generated_path = "${var.k8s_sources_path != "" ? var.k8s_sources_path : "${path.root}/k8s/"}generated/${var.name}"
}

output "ns_info" {
  value = {
    "name"            = var.name
    "ci_deploy_token" = kubernetes_service_account.ci_deploy.default_secret_name                  // backward compatible with older gitlab integration, remove in next version
    "dummy"           = "To wait for NS to be read - ${kubernetes_namespace.ns.metadata[0].name}" // .0.name fixes plan/apply error
  }
}

output "ci_deploy_secret" {
  value = {
    data = data.kubernetes_secret.ci_deploy_token.data // string during plan, map after refresh
  }
}
