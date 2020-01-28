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

`vault_sync` will not be configured by default and in order to enable it, you need to include a `vault_sync` block. Working mode will depend on given parameters and whether your project is in shared VPC or not.

* `addr`: Vault address, must be provided
* `base_path`: base path for the Vault secrets, must be provided
* `secrets_path`: path to Vault secrets. Defaults to `ns-{name}-secrets`
* `target_secret_name`: Kubernetes secret name. Defaults to `kubernetes_secret.k8s_secrets[0].metadata[0].name` aka `{name}-secrets`
* `reconcile_period`: duration between Vault checks. Defaults to `10m`. This parameter accepts Golang's `time.Time` values, which are in the following format: `30s`, `10m`, `1h`, `1h10m30s`

#### Mode 1: Projects in shared VPC

```hcl-terraform
module "example_namespace" {
  source  = "kiwicom/namespace/kubernetes"
  version = "~> 2.0.0"

  ...
  
  vault_sync = {
    addr               = "https://your-vault-address"
    base_path          = var.VAULT_PROJECT_SECRETS_PATH
    secrets_path       = ""
    target_secret_name = ""
    reconcile_period   = ""
  }
}
```

For projects that are in shared VPC (`shared_vpc = true`), secrets from Vault will be synchronized automatically after `reconcile_period` (default: `10m`) and after each `terraform apply`.

You need to provide at least `addr` and `base_path` while the other parameters are configurable.

Although, this only works with `k8s-vault-operator` which is currently only in private mode.

##### How does it work?

The operator will subscribe to all `Secret` Kubernetes objects and ignore anything that does not have a `vault-sync-secret` name. For the valid `Secret`'s, it will check Vault path at `base_path/secrets_path` and compare values to `target_secret_name` in Kubernetes every `reconcile_period`. If they don't match, it will update `target_secret_name` in Kubernetes.

**Note**: because the operator subscribes to all `Secret`'s, you will see them in the output of the operator, but they will immediately be ignored until their contents change - at that point the operator will grab them again for another round of ignore. Here is an example of such `Secret`:

> {"level":"info","ts":1578895264.4219866,"logger":"controller_autosync","msg":"Reconciling Secret","Request.Namespace":"gds-queue-handler","Request.Name":"gitlab"}

A valid `Secret` will look like this (note the name `vault-sync-secret`):

> {"level":"info","ts":1578903069.236135,"logger":"controller_autosync","msg":"Reconciling Secret","Request.Namespace":"gds-queue-handler","Request.Name":"vault-sync-secret"}

#### Mode 2: Projects not in shared VPC

```hcl-terraform
module "example_namespace" {
  source  = "kiwicom/namespace/kubernetes"
  version = "~> 2.0.0"

  ...

  shared_vpc = false
  
  vault_sync = {
    addr               = ""
    base_path          = var.VAULT_PROJECT_SECRETS_PATH
    secrets_path       = ""
    target_secret_name = ""
    reconcile_period   = ""
  }
}
```

For projects that are not in shared VPC (`shared_vpc = false`), secrets from Vault will be synchronized only after each `terraform apply`.

You need to provide only `base_path`, `secrets_path` is configurable while all the other parameters can be set to `""`.
