# terraform-kubernetes-namespace

## Usage

```hcl-terraform
module "example_namespace" {
  source  = "kiwicom/namespace/kubernetes"
  version = "~> 2.0.0"

  project_id              = "gcp-project-id"
  name                    = "example-namespace"
  gitlab_rancher_password = "GITLAB_REGISTRY_PASSWORD"
  run_template_dir        = false
  
  vault_sync = {
    addr               = "https://your-vault-address"
    base_path          = var.VAULT_PROJECT_SECRETS_PATH
    secrets_path       = ""
    target_secret_name = ""
    reconcile_period   = ""
  }
}
```

### vault_sync

Note: `vault_sync` only works with `k8s-vault-operator` which is currently in private mode.

When `vault_sync` is enabled, secrets from Vault will be synchronized automatically after `reconcile_period` (default: `10m`) and after each `terraform apply`.

By default, secrets will be synchronized from `var.VAULT_PROJECT_SECRETS_PATH/ns-${var.name}-secrets` path.

`vault_sync` will not be configured by default and in order to enable it, you need to include a `vault_sync` block. If you do not set `addr` and `base_path`, `vault_sync` will not be configured.

* `addr`: Vault address, must be provided
* `base_path`: base path for the Vault secrets, must be provided
* `secrets_path`: path to Vault secrets. Defaults to `ns-{name}-secrets`
* `target_secret_name`: Kubernetes secret name. Defaults to `kubernetes_secret.k8s_secrets[0].metadata[0].name` aka `{name}-secrets`
* `reconcile_period`: duration between Vault checks. Defaults to `10m`. This parameter accepts Golang's `time.Time` values, which are in the following format: `30s`, `10m`, `1h`, `1h10m30s`

This will create a `vault-sync-secret` in your namespace with all the information the operator needs to perform a sync.

#### How does it work?

The operator will subscribe to all `Secret` Kubernetes objects and ignore anything that does not have a `vault-sync-secret` name. For the valid `Secret`'s, it will check Vault path at `base_path/secrets_path` and compare values to `target_secret_name` in Kubernetes every `reconcile_period`. If they don't match, it will update `target_secret_name` in Kubernetes.

**Note**: because the operator subscribes to all `Secret`'s, you will see them in the output of the operator, but they will immediately be ignored until their contents change - at that point the operator will grab them again for another round of ignore. Here is an example of such `Secret`:

> {"level":"info","ts":1578895264.4219866,"logger":"controller_autosync","msg":"Reconciling Secret","Request.Namespace":"gds-queue-handler","Request.Name":"gitlab"}

A valid `Secret` will look like this (note the name `vault-sync-secret`):

> {"level":"info","ts":1578903069.236135,"logger":"controller_autosync","msg":"Reconciling Secret","Request.Namespace":"gds-queue-handler","Request.Name":"vault-sync-secret"}
