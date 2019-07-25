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
