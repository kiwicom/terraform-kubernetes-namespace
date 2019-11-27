resource "kubernetes_namespace" "ns" {
  metadata {
    name   = var.name
    labels = var.labels
  }
}

resource "kubernetes_secret" "gitlab_docker_registry_credentials" {
  metadata {
    name      = "gitlab"
    namespace = kubernetes_namespace.ns.metadata[0].name
  }

  data = {
    ".dockercfg" = "{\"${var.gitlab_registry}\":{\"username\":\"${var.gitlab_rancher_username}\",\"password\":\"${var.gitlab_rancher_password}\"}}"
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

data "vault_generic_secret" "k8s" {
  count = var.vault_path == "" ? 0 : 1
  path  = var.vault_path
}

data "vault_generic_secret" "namespace_secrets" {
  count = var.vault_base_path == "" ? 0 : 1
  path  = "${var.vault_base_path}/ns-${var.name}-secrets"
}

resource "template_dir" "k8s" {
  count           = var.run_template_dir == true ? 1 : 0
  source_dir      = local.k8s_sources_templates_path
  destination_dir = local.k8s_sources_generated_path

  vars = merge(var.additional_k8s_vars)
}

// TODO: remove (var.project_id == "" || var.vault_path == "") after migration
resource vault_policy "project_namespace_policy" {
  count = (var.project_id == "" || var.vault_path == "") || var.vault_sync_disable ? 0 : 1
  name  = "tf-gcp-projects-${var.project_id}-${var.name}-read"

  policy = <<EOT
# Allow tokens to look up their own properties
path "auth/token/lookup-self" {
    capabilities = ["read"]
}

path "secret/gcp-project/${var.project_id}/ns-${var.name}-*" {
  policy = "read"
}
EOT
}

// TODO: remove (var.project_id == "" || var.vault_path == "") after migration
resource "vault_token_auth_backend_role" "project_namespace_role" {
  count            = (var.project_id == "" || var.vault_path == "") || var.vault_sync_disable ? 0 : 1
  role_name        = "tf-gcp-projects-${var.project_id}-${var.name}-read"
  allowed_policies = [vault_policy.project_namespace_policy[0].name]
  orphan           = true
}

resource "vault_token" "project_namespace_token" {
  count             = (var.project_id == "" || var.vault_path == "") || var.vault_sync_disable ? 0 : 1
  display_name      = "tf-gcp-projects-${var.project_id}-${var.name}-read"
  role_name         = vault_token_auth_backend_role.project_namespace_role[0].role_name
  policies          = [vault_policy.project_namespace_policy[0].name]
  no_default_policy = true
  renewable         = true
  ttl               = 15768000 // 0.5 years
}

// TODO: switch completely to vault_base_path after migration
resource "kubernetes_secret" "k8s_secrets" {
  count = var.vault_path == "" ? (var.vault_base_path == "" ? 0 : 1) : 1

  metadata {
    name      = "${kubernetes_namespace.ns.metadata[0].name}-secrets"
    namespace = kubernetes_namespace.ns.metadata[0].name
  }

  data  = var.vault_path == "" ? data.vault_generic_secret.namespace_secrets[0].data : data.vault_generic_secret.k8s[0].data
}

resource "kubernetes_secret" "vault_token_secret" {
  count = (var.project_id == "" || var.vault_path == "") || var.vault_sync_disable ? 0 : 1

  metadata {
    name      = "vault-sync-secret"
    namespace = kubernetes_namespace.ns.metadata[0].name
  }

  data = {
    VAULT_TOKEN        = vault_token.project_namespace_token[0].client_token
    VAULT_ADDR         = var.vault_addr
    VAULT_PATH         = data.vault_generic_secret.namespace_secrets[0].path
    TARGET_SECRET_NAME = var.vault_target_secret_name
    RECONCILE_PERIOD   = var.vault_reconcile_period
  }
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
