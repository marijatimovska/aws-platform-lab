# GitOps tree

Everything inside the cluster is owned by ArgoCD, which syncs this directory —
the pipeline never runs `helm install` for apps.

```
bootstrap/argocd-values.yaml   # values used when the script installs ArgoCD itself
templates/*.tmpl.yaml          # env-agnostic templates with __PLACEHOLDERS__
clusters/<env>/                # RENDERED manifests ArgoCD actually syncs (committed!)
```

Workflow after `terraform apply` of an environment:

1. `./scripts/render-gitops.sh <env>` — reads Terraform outputs and renders
   `templates/` into `gitops/clusters/<env>/` (account IDs, IRSA role ARNs, the
   DB secret name, S3 URL...).
2. `git add gitops/clusters/<env> && git commit && git push` — rendered config is
   reviewable like any other change. This commit IS the deployment.
3. First time only: `./scripts/bootstrap-gitops.sh <env>` installs ArgoCD and
   applies the root Application; from then on ArgoCD pulls this repo.

Why render-and-commit instead of templating inside ArgoCD: the seam between
Terraform-owned values (role ARNs, URLs) and GitOps-owned manifests is explicit,
reviewable, and survives tool churn. The same pattern at scale is done with
ApplicationSets or a config repo written by the infra pipeline.

NOTE: ArgoCD must be able to read this repository. Easiest for a portfolio:
make the repo public. Private repo: add it in ArgoCD with a deploy key
(Settings → Repositories) before the root app can sync.
