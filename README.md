# terraform-kubernetes-namespace

## Usage

```hcl-terraform
module "example_project" {
  source  = "kiwicom/namespace/kubernetes"
  version = "~> 2.0.0"

  project_id              = "gcp-project-id"
  name                    = "example-project"
  gitlab_rancher_password = "GITLAB_REGISTRY_PASSWORD"
  vault_path              = "secret/ns-example-project-secrets"
  run_template_dir        = false
  
  vault_sync = {
    addr = "https://your-vault-address"
    base_path = var.VAULT_PROJECT_SECRETS_PATH
    target_secret_name = ""
    reconcile_period = ""
  }
}
```

### vault_sync

When `vault_sync` is enabled, it means that secrets from Vault will be synchronized automatically after `reconcile_period` and after every `terraform apply`.

By default, secrets will be synchronized from `var.VAULT_PROJECT_SECRETS_PATH/ns-${var.name}-secrets` path.

`vault_sync` will not be configured by default and in order to enable it, you need to include a `vault_sync` block. If you do not set `addr` and `base_path`, `vault_sync` will not be configured.

* `addr` -> Vault address. It cannot be empty
* `base_path` -> base path for the Vault. It cannot be empty
* `target_secret_name` -> if empty, will be set to `kubernetes_secret.k8s_secrets[0].metadata[0].name`
* `reconcile_period` -> if empty, will be set to `5m`
