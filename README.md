# aws-platform-lab

A layered, GitOps-driven Kubernetes platform on AWS: **Terraform builds the platform,
ArgoCD fills it.** Three environments (dev / qa / prod), one state file per
environment × layer, and no credentials in git.

```
 GitOps (ArgoCD) ─ metrics-server · External Secrets · webapp (Helm)     daily
 40-observability ─ CloudWatch alarms · dashboard · SNS email             weekly
 30-data          ─ RDS (Multi-AZ prod) · Secrets Manager · S3 · IRSA     monthly
 20-platform      ─ EKS · node group · ALB · OIDC · access entries        monthly
 10-network       ─ VPC · public/app/db subnets × 2 AZs · NAT             rarely
 bootstrap        ─ state bucket · GitHub OIDC role · budgets             once
```

## Highlights

- **Layered Terraform.** Four independently planned and applied layers wired by
  `terraform_remote_state`, reusable modules, and environments that differ only in tfvars.
- **GitOps.** ArgoCD app-of-apps with sync waves. App changes deploy by merging, and
  roll back with `git revert`.
- **Secrets done right.** Secrets Manager → External Secrets Operator (IRSA, scoped to
  one secret) → Kubernetes Secret → pod. Nothing sensitive in git.
- **High availability.** 2 AZs, zone-spread pods, PDB, ASG + ALB health checks, RDS
  Multi-AZ automatic failover in prod.
- **Elasticity at two layers.** HPA for pods (70% CPU); node scaling out at ≥70% and
  in at ≤40%.
- **CI/CD.** PRs run fmt, validate, tflint, Checkov, helm lint, and a plan for every
  env×layer. Merging applies the layers in order. qa/prod are promoted manually, with
  an approval gate on prod. There's also a drift-detection workflow.
- **FinOps.** $30/month and $5/day budget alerts, clean destroys (no orphaned load
  balancers), and destroy-daily scripts.

## Quick start

```bash
# once: bootstrap + GitHub variables          (docs/GUIDE.md §0-2)
./scripts/deploy-env.sh dev                    # all layers, in order (~25-30 min)
./scripts/render-gitops.sh dev                 # first time per env, then commit + push
./scripts/bootstrap-gitops.sh dev              # first time; deploy-env does it after that
./scripts/tf.sh dev platform output -raw app_url
./scripts/destroy-all.sh                       # end of every session
```

## Docs

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md):** layers, state layout, ownership, design decisions, known simplifications
- **[GUIDE.md](docs/GUIDE.md):** step-by-step setup, change flows, daily routine, troubleshooting
- **[COST.md](docs/COST.md):** per-hour costs and how to stay within $30/month
- **[BREAK-IT-LAB.md](docs/BREAK-IT-LAB.md):** 20 incidents to practice, plus upgrade roadmap
- **[postmortems/](docs/postmortems/):** your incident write-ups
