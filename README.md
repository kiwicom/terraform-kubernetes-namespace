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
}
```
