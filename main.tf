locals {
  gcr_dockercfg            = var.gcr_sa != "" ? ",\"eu.gcr.io\":{\"username\":\"_json_key\",\"password\":${jsonencode(base64decode(var.gcr_sa))}}" : ""
  rancher2_annotations     = var.rancher2_project_id != "" ? {"field.cattle.io/projectId" = var.rancher2_project_id} : {}
  namespace_annotations    = merge(
    data.external.gitlab_ci_project_info.result,
    local.rancher2_annotations,
    /*other annotations */
  )
}

# doesn't matter if not defined
data "external" "gitlab_ci_project_info" {
  program = ["bash", "-c", "jq -n --arg CI_PROJECT_ID \"$CI_PROJECT_ID\" --arg CI_PROJECT_PATH \"$CI_PROJECT_PATH\" '{\"CI_PROJECT_ID\":$CI_PROJECT_ID, \"CI_PROJECT_PATH\":$CI_PROJECT_PATH}'"]
}

resource "kubernetes_namespace" "ns" {
  metadata {
    name        = var.name
    labels      = var.labels
    annotations = local.namespace_annotations
  }
}

resource "kubernetes_secret" "gitlab_docker_registry_credentials" {
  metadata {
    name      = "gitlab"
    namespace = kubernetes_namespace.ns.metadata[0].name
  }

  data = {
    ".dockercfg" = "{\"${var.gitlab_registry}\":{\"username\":\"${var.gitlab_rancher_username}\",\"password\":\"${var.gitlab_rancher_password}\"}${local.gcr_dockercfg}}"
  }

  type = "kubernetes.io/dockercfg"
}

resource "kubernetes_limit_range" "limits" {
  metadata {
    name      = "default-limit-range"
    namespace = kubernetes_namespace.ns.metadata[0].name
  }

  spec {
    limit {
      type = "Container"

      default_request = {
        cpu    = var.cpu_request
        memory = var.memory_request
      }

      default = {
        cpu    = var.cpu_limit
        memory = var.memory_limit
      }
    }
  }
}

resource "template_dir" "k8s" {
  count           = var.run_template_dir == true ? 1 : 0
  source_dir      = local.k8s_sources_templates_path
  destination_dir = local.k8s_sources_generated_path

  vars = merge(var.additional_k8s_vars)
}

resource "google_service_account" "ci_deploy" {
  count        = var.should_create_deploy_user
  account_id   = "ci-${urlencode(kubernetes_namespace.ns.metadata[0].name)}-ns"
  display_name = "CI/CD ${kubernetes_namespace.ns.metadata[0].name} ns"
}

resource "google_project_iam_member" "ci_deploy" {
  count  = var.should_create_deploy_user
  role   = "roles/container.clusterViewer"
  member = "serviceAccount:${google_service_account.ci_deploy[0].email}"
}

resource "kubernetes_cluster_role" "ci_deploy" {
  metadata {
    name = "ci-deploy-user-${kubernetes_namespace.ns.metadata[0].name}"
  }

  rule {
    api_groups = [
      "*"]
    resources = [
      "nodes"]
    verbs = [
      "get",
      "list",
      "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "ci_deploy" {
  metadata {
    name = "ci-deploy-user-${kubernetes_namespace.ns.metadata[0].name}"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "ci-deploy-user-${kubernetes_namespace.ns.metadata[0].name}"
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name = concat(google_service_account.ci_deploy.*.email, [
      var.deploy_user])[0]
    namespace = kubernetes_namespace.ns.metadata[0].name
  }
}

resource "kubernetes_cluster_role_binding" "ci_deploy_k8s" {
  metadata {
    name = "ci-deploy-user-k8s-${kubernetes_namespace.ns.metadata[0].name}"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "ci-deploy-user-${kubernetes_namespace.ns.metadata[0].name}"
  }

  subject {
    api_group = ""
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.ci_deploy.metadata[0].name
    namespace = kubernetes_namespace.ns.metadata[0].name
  }
}

resource "kubernetes_role" "ci_deploy" {
  metadata {
    name      = "ci-deploy-user"
    namespace = kubernetes_namespace.ns.metadata[0].name
  }

  rule {
    api_groups = [
      "*"]
    resources = [
      "*"]
    verbs = [
      "*"]
  }
}

resource "kubernetes_role_binding" "ci_deploy" {
  metadata {
    name      = "ci-deploy-user-binding"
    namespace = kubernetes_namespace.ns.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "ci-deploy-user"
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name = concat(google_service_account.ci_deploy.*.email, [
      var.deploy_user])[0]
  }
}

resource "kubernetes_role" "ci_deploy_read_dd_config" {
  metadata {
    name      = "ci-${kubernetes_namespace.ns.metadata[0].name}-dd-config"
    namespace = "system"
  }

  rule {
    api_groups = [
      ""]
    resources = [
      "configmaps"]
    resource_names = [
      "dd-agent-config"
    ]
    verbs = [
      "get"]
  }
}

resource "kubernetes_role_binding" "ci_deploy_read_dd_config" {
  metadata {
    name      = "ci-${kubernetes_namespace.ns.metadata[0].name}-binding-dd-config"
    namespace = "system"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.ci_deploy_read_dd_config.metadata[0].name
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name = concat(google_service_account.ci_deploy.*.email, [
      var.deploy_user])[0]
    namespace = kubernetes_namespace.ns.metadata[0].name
  }
}

resource "kubernetes_role_binding" "ci_deploy_k8s_read_dd_config" {
  metadata {
    name      = "ci-${kubernetes_namespace.ns.metadata[0].name}-binding-dd-config-k8s"
    namespace = "system"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.ci_deploy_read_dd_config.metadata[0].name
  }

  subject {
    api_group = ""
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.ci_deploy.metadata[0].name
    namespace = kubernetes_namespace.ns.metadata[0].name
  }
}

resource "kubernetes_service_account" "ci_deploy" {
  metadata {
    name      = "ci-deploy-user"
    namespace = kubernetes_namespace.ns.metadata[0].name
  }
}

data "kubernetes_secret" "ci_deploy_token" {
  metadata {
    name      = kubernetes_service_account.ci_deploy.default_secret_name
    namespace = kubernetes_namespace.ns.metadata[0].name
  }
}

resource "kubernetes_role_binding" "ci_deploy_k8s" {
  metadata {
    name      = "ci-deploy-user-binding-k8s"
    namespace = kubernetes_namespace.ns.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "ci-deploy-user"
  }

  subject {
    api_group = ""
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.ci_deploy.metadata[0].name
    namespace = kubernetes_namespace.ns.metadata[0].name
  }
}
