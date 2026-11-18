# Architecture

## The core idea: split by rate of change and blast radius

Each layer has its **own Terraform state**, its own plan/apply, and can be changed
without touching the others. A broken app deploy cannot affect the VPC; a VPC change
is planned and reviewed on its own.

```
                 ┌───────────────────────────────────────────────────────────┐
  in-cluster     │  GitOps (ArgoCD)        gitops/clusters/<env>/            │  changes: daily
  (git-owned)    │   metrics-server · External Secrets · eso-config · webapp │
                 └──────────────▲────────────────────────────────────────────┘
                                │ render-gitops.sh (role ARNs, URLs, secret name)
                 ┌──────────────┴────────────────────────────────────────────┐
  40-observability│ SNS alerts · CloudWatch alarms · dashboard               │  changes: weekly
                 ├───────────────────────────────────────────────────────────┤
  30-data        │ RDS (Multi-AZ prod) · Secrets Manager · S3 static ·       │  changes: monthly
                 │ IRSA roles (webapp, external-secrets)                     │
                 ├───────────────────────────────────────────────────────────┤
  20-platform    │ EKS cluster · node group · node scaling · ALB ·           │  changes: monthly
                 │ OIDC provider · access entries                            │
                 ├───────────────────────────────────────────────────────────┤
  10-network     │ VPC · public / app / db subnets × 2 AZs · NAT · routes    │  changes: rarely
                 ├───────────────────────────────────────────────────────────┤
  bootstrap      │ state bucket · GitHub OIDC role · budgets ($30/mo, $5/day)│  once per account
                 └───────────────────────────────────────────────────────────┘
```

Layers read each other through `terraform_remote_state`, which is read-only and
goes downward only. A layer never writes into another layer's state.

| Layer | Reads from | Exposes (outputs) |
|---|---|---|
| 10-network | — | vpc_id, public/app/db subnet IDs |
| 20-platform | network | cluster name, cluster SG, OIDC provider, ALB suffixes, node ASG |
| 30-data | network, platform | DB identifier, **secret name**, bucket, IRSA role ARNs |
| 40-observability | platform, data | dashboard URL, SNS topic |

**Apply order:** network → platform → data → observability.
**Destroy order:** the reverse. `scripts/deploy-env.sh` and `scripts/destroy-all.sh`
enforce both.

## State layout

One bucket per account, one state file per **environment × layer**:

```
s3://platlab-tfstate-<account>/
  env/dev/network.tfstate        env/qa/...        env/prod/...
  env/dev/platform.tfstate
  env/dev/data.tfstate
  env/dev/observability.tfstate
```

Locking uses S3 native lockfiles (`use_lockfile = true`, Terraform ≥ 1.10), so no
DynamoDB table is needed.

## Repository layout

```
terraform/
  bootstrap/                  # local state, run once
  modules/                    # reusable building blocks, no env knowledge
    network/ alb/ eks/ rds/ s3_static/ monitoring/ irsa_role/
  layers/                     # root modules = deployable units
    10-network/ 20-platform/ 30-data/ 40-observability/
  environments/<env>/<layer>.tfvars   # the ONLY place envs differ
apps/webapp/                  # Helm chart (deployed by ArgoCD, not by CI)
gitops/
  bootstrap/argocd-values.yaml
  templates/                  # env-agnostic, __PLACEHOLDER__ values
  clusters/<env>/             # rendered + committed; what ArgoCD syncs
scripts/                      # tf.sh, deploy-env, render-gitops, bootstrap-gitops, destroy-all
.github/workflows/            # ci (lint+plan per env×layer), deploy (layered), drift
```

**Rules that keep it clean:**
- Modules never contain environment names, account IDs or hardcoded sizes.
- Layers contain wiring only (module calls + remote state). Logic lives in modules.
- Environments differ **only** in tfvars. If two envs need different *code*, that's a smell.

## Who owns what

| Concern | Owner | How it changes |
|---|---|---|
| AWS resources | Terraform layers | PR → plan per env×layer → merge → pipeline applies |
| Everything inside the cluster | ArgoCD | Commit to `apps/` or `gitops/` → ArgoCD syncs (no pipeline run) |
| Values crossing the seam (role ARNs, URLs, secret name) | `render-gitops.sh` | Re-render + commit; stable across rebuilds because names are deterministic |
| Static website files | Pipeline (`aws s3 sync`) | Commit to `app-static/` |

The seam is explicit on purpose. Terraform builds the platform, git fills it, and the
handoff is a reviewable commit.

## Request path

```
browser → ALB (public subnets, both AZs)
        → target group → NodePort 30080 on worker nodes (private app subnets)
        → kube-proxy → webapp Service → pod (zone-spread)
pod → env vars from k8s Secret "webapp-db"
        ← External Secrets Operator (IRSA, scoped to one secret)
        ← AWS Secrets Manager "platlab/<env>/db" (written by the data layer)
```

## Key design decisions (and the interview answer for each)

**1. ALB is owned by Terraform, not by an Ingress controller.**
An Ingress-created ALB is invisible to Terraform and gets orphaned when the cluster is
destroyed, and it keeps billing. Owning it in the platform layer keeps destroys clean
and keeps the ALB alarms in code. The trade-off is less flexibility: there's one
target group and routing by path or host needs Terraform changes. Migrating to the
AWS Load Balancer Controller is a listed upgrade.

**2. Deterministic secret name; the password lives in Terraform state.**
The data layer generates the DB password and writes it to `platlab/<env>/db`. Git can
reference that stable name, so the GitOps chain works without credentials in git. The
cost is that the password exists in the (encrypted, private) state bucket. The
production alternative is an RDS-managed secret with rotation, or IAM database auth,
with the app reading the secret ARN from config.

**3. IRSA roles live in the data layer, not the platform layer.**
A role's *permissions* point at data resources (a bucket, a secret). Its *trust*
points at the cluster's OIDC provider (platform output). Putting the roles next to
what they grant access to means adding a bucket never means touching the cluster layer.

**4. Explicit EKS access entries, no implicit "creator is admin".**
The CI role and your admin user are both declared in code. This is auditable, and it
avoids a conflict when the pipeline creates the cluster itself.

**5. Two layers of elasticity.**
The HPA scales pods at 70% CPU. CloudWatch alarms scale nodes out at ≥70% and in at
≤40%. Production EKS would use Karpenter for the node layer; the alarm approach is a
deliberate, transparent simplification.

## Known simplifications (keep this list — interviewers love it)

| Lab choice | Production choice |
|---|---|
| CI role has `AdministratorAccess` | Scoped policy, plus a separate read-only plan role for PRs |
| All envs in one AWS account | AWS Organizations: one account per env, SCPs, SSO |
| Single NAT gateway | One NAT per AZ |
| Node scaling via CloudWatch alarms | Karpenter |
| Every env's ArgoCD tracks `main` | Promotion by pinned revisions per env (e.g. prod tracks a release tag) |
| Helm charts at `targetRevision: "*"` | Pinned chart versions, upgraded via PRs (Renovate) |
| S3 static site is public | CloudFront + Origin Access Control, private bucket |
| HTTP only | Route 53 + ACM certificate, HTTPS listener |
| Checkov in soft-fail mode | Hard fail with documented, reviewed exceptions |
| DB password in Terraform state | RDS-managed secret + rotation, or IAM DB auth |
| ArgoCD UI via port-forward, admin password | SSO (Dex/OIDC), RBAC per team |
