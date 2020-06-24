## Service Account
resource "kubernetes_service_account" "default" {
  metadata {
    name      = var.name
    namespace = var.name
  }
}

## Basic policy
resource "vault_policy" "use" {
  name   = "kw/secret/${var.base_path}/${var.name}"
  policy = <<EOT
path "kw/secret/data/${var.base_path}/${var.name}/*" {
  capabilities = ["read",]
}
path "kw/secret/metadata/${var.base_path}/${var.name}/*" {
  capabilities = ["read", "list"]
}
EOT
}

locals {
  path_for_listing = split("/", "${var.base_path}/${var.name}")
}

data "vault_policy_document" "maintainers_policy" {
  rule {
    description  = "access namespace, stage specific secrets"
    path         = "kw/secret/data/${var.base_path}/${var.name}/*"
    capabilities = ["create", "update", "read", "delete", "list"]
  }

  rule {
    description  = "access namespace, stage specific metadata"
    path         = "kw/secret/metadata/${var.base_path}/${var.name}/*"
    capabilities = ["create", "update", "read", "delete", "list"]
  }

  dynamic rule {
    for_each = local.path_for_listing
    content {
      path         = "kw/secret/metadata/${join("/", slice(local.path_for_listing, 0, rule.key))}"
      capabilities = ["list"]
      description  = "list of subpath"
    }
  }
}

resource "vault_policy" "maintainer" {
  name   = "kw/secret/${var.base_path}/${var.name}-maintainer"
  policy = data.vault_policy_document.maintainers_policy.hcl
}

# TODO load policies from var.vault_additional_policies via data to ensure it exists
## kubernetes_auth role
resource "vault_kubernetes_auth_backend_role" "default" {
  backend                          = "kw/${var.base_path}"
  bound_service_account_names      = ["*"]
  bound_service_account_namespaces = [var.name]
  role_name                        = var.name
  token_policies = concat(
    [vault_policy.use.name],
    var.vault_additional_policies
  )
}

data "vault_identity_group" "ns_maintainers" {
  for_each   = toset(var.okta_maintainer_groups)
  group_name = each.value
}

resource "vault_identity_group_policies" "ns_maintainers" {
  for_each  = toset(var.okta_maintainer_groups)
  group_id  = data.vault_identity_group.ns_maintainers[each.value].group_id
  policies  = [vault_policy.maintainer.name]
  exclusive = false
}
