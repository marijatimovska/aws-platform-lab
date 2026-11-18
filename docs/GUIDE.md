# Setup & Deployment Guide

From a fresh AWS account to a layered, GitOps-driven EKS platform. Follow in order.
All commands run from the repository root.

---

## 0. Prerequisites (one-time)

1. **AWS account** with your free-tier credits. MFA on the root user.
2. **Create an IAM user named `marija-admin`** with `AdministratorAccess` and MFA.
   The platform layer grants this exact user `kubectl` admin on every cluster.
   If you name it differently, or use SSO, set `cluster_admin_user` or
   `extra_cluster_admin_arns` in `terraform/environments/<env>/platform.tfvars`.
3. **Install:** Terraform ≥ 1.10, AWS CLI v2, kubectl, Helm, git.
4. **Credentials:** `aws configure` with `marija-admin`'s access key, then check with
   `aws sts get-caller-identity`. It should show `...:user/marija-admin`.
5. **GitHub repository `aws-platform-lab`, set to PUBLIC.** ArgoCD has to read the repo.
   A public repo is simplest, and it's a portfolio piece anyway. The repo contains
   no credentials. For a private repo, add a deploy key in ArgoCD before step 5.
6. **Format once, then push:**
   ```bash
   terraform fmt -recursive terraform/     # CI fails on unformatted code
   git init && git add -A && git commit -m "Layered AWS EKS platform"
   git branch -M main
   git remote add origin https://github.com/YOUR_USERNAME/aws-platform-lab.git
   git push -u origin main
   ```

> **Already ran the first project (`aws-devops-lab`) in this account?** An account can
> have only one GitHub OIDC provider. Set `create_github_oidc_provider = false` in this
> project's bootstrap tfvars. Also, both projects' budgets would email you. Destroy the
> old project's bootstrap (`cd aws-devops-lab/terraform/bootstrap && terraform destroy`,
> after emptying its state bucket), or keep both and accept duplicate alerts.
> Never run both projects' environments at the same time.

---

## 1. Bootstrap (once per account)

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars   # set github_repo = "YOUR_USERNAME/aws-platform-lab"
terraform init && terraform apply
cd ../..
```

This creates the `platlab-tfstate-<account>` state bucket, the `platlab-github-actions`
OIDC role, and the budgets: $30/month with alerts at 50/80/100% plus forecast, and a
$5/day tripwire, all sent to marijatimovska@gmail.com.

Keep `terraform/bootstrap/terraform.tfstate` safe. It's local and gitignored.

---

## 2. GitHub wiring (once)

- **Settings → Secrets and variables → Actions → Variables:**
  `AWS_ROLE_ARN` = bootstrap output `github_actions_role_arn`, `AWS_REGION` = `eu-central-1`
- **Settings → Environments:** create `dev`, `qa` and `prod`. On `prod`, add yourself under **Required reviewers**.

---

## 3. Deploy the dev infrastructure (layer by layer)

The first time, run each layer by hand so you see the separation:

```bash
./scripts/tf.sh dev network apply          # ~3 min   VPC, subnets, NAT
./scripts/tf.sh dev platform apply         # ~12-15 min  EKS, nodes, ALB
./scripts/tf.sh dev data apply             # ~8-12 min   RDS, secret, S3, IRSA roles
./scripts/tf.sh dev observability apply    # ~1 min   alarms, dashboard, SNS
./scripts/deploy-static.sh dev
```

After that, `./scripts/deploy-env.sh dev` does all of the above in order.

Things to notice:
- Each run prints `state=s3://.../env/dev/<layer>.tfstate`, one state per layer.
- `./scripts/tf.sh dev platform output` lists what this layer hands to the next one.
- **Confirm the SNS subscription email.** Alarms don't reach you until you do.

---

## 4. Render GitOps for dev (first time per environment)

```bash
./scripts/render-gitops.sh dev
git diff --stat                     # review gitops/clusters/dev/*
git add gitops/clusters/dev && git commit -m "Render gitops (dev)" && git push
```

The script reads Terraform outputs (IRSA role ARNs, DB secret name, S3 URL, repo URL)
and fills in the templates. These values are **deterministic**: bucket, role and
secret names don't change when you destroy and rebuild. So you render once per
environment, and every later rebuild reuses the same commit.

---

## 5. Hand the cluster to ArgoCD

```bash
./scripts/bootstrap-gitops.sh dev
kubectl get applications -n argocd -w
```

ArgoCD installs metrics-server and External Secrets (wave 0), then the
SecretStore/ExternalSecret (wave 1), then the webapp (wave 2). Expect 3-5 minutes.
The first sync of `eso-config` can show errors until the ESO CRDs exist. Its retry
policy takes care of that, so let it settle.

From now on, `deploy-env.sh` re-runs this step automatically after every rebuild.

**ArgoCD UI:**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443    # https://localhost:8080
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

---

## 6. Verify

| Check | Command |
|---|---|
| App up | `./scripts/tf.sh dev platform output -raw app_url` → browser shows pod, node and **Database** row |
| Secret chain works | `kubectl get externalsecret webapp-db` → `SecretSynced`; `kubectl get secret webapp-db` |
| Pods zone-spread | `kubectl get pods -o wide` and compare nodes; `kubectl get nodes -L topology.kubernetes.io/zone` |
| HPA live | `kubectl get hpa` shows CPU % against the 70% target |
| Everything synced | `kubectl get applications -n argocd` shows all `Synced` / `Healthy` |
| Dashboard | `./scripts/tf.sh dev observability output -raw dashboard_url` |

---

## 7. How changes flow

| You change | What happens |
|---|---|
| `terraform/**` | PR: fmt, validate, tflint, checkov, and a plan for every env×layer (layers whose upstream isn't deployed are skipped). Merge: pipeline applies **dev** in layer order and re-bootstraps ArgoCD. |
| `apps/webapp/**` or `gitops/**` | **No pipeline deploy.** Merge, and ArgoCD syncs within ~3 min. Roll back with `git revert`. |
| `app-static/**` | Merge, and the pipeline syncs to the dev bucket. |
| Promote to qa/prod | Actions → *Deploy* → *Run workflow* → target `qa` or `prod`. Prod waits for your approval. |

qa and prod never start from a plain push. Each running EKS environment costs about
$0.25/hour, so promotion is always a deliberate action.

**First time on qa/prod:** after the infra exists, run `./scripts/render-gitops.sh qa`,
commit and push, then `./scripts/bootstrap-gitops.sh qa` (or re-run the workflow,
which bootstraps ArgoCD automatically once the rendered folder exists).

---

## 8. Daily routine

```bash
./scripts/deploy-env.sh dev       # ~25-30 min: layers + static + ArgoCD; apps sync themselves
# ... work, break things, fix them ...
./scripts/destroy-all.sh          # reverse layer order, every env
```

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `does not have an attribute named "vpc_id"` | An upstream layer isn't applied in this env. Apply in order network → platform → data → observability |
| `DependencyViolation` destroying network | Something upstream still exists. Destroy in reverse order (`destroy-all.sh` does) |
| `kubectl` Unauthorized | You aren't `marija-admin`, or that user didn't exist when platform was applied. Check `aws sts get-caller-identity`, then re-apply platform |
| Platform apply fails creating an access entry | The principal doesn't exist. Create the `marija-admin` user, or set `cluster_admin_user = ""` |
| ArgoCD app `Unknown` / repo errors | Repo is private, or `gitops/clusters/<env>` wasn't pushed |
| ExternalSecret `SecretSyncError` | IRSA annotation wrong (re-render), or data layer not applied |
| Pods `Pending` | Out of pod slots (t3.small ≈ 11 pods). Keep 2 nodes, or see prefix delegation in BREAK-IT-LAB |
| HPA `<unknown>` | metrics-server app not synced yet |
| Bootstrap: OIDC provider already exists | Set `create_github_oidc_provider = false` |
| Secrets Manager: name scheduled for deletion | An older secret with the same name is pending deletion. Run `aws secretsmanager delete-secret --secret-id platlab/dev/db --force-delete-without-recovery` |
