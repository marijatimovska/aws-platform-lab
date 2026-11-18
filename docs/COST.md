# Cost Management

## Per-hour view (what actually matters with destroy-daily)

Ballpark eu-central-1 on-demand rates. Your Billing console is the source of truth.

| Component | ≈ $/hour | ≈ $/month if left running |
|---|---|---|
| EKS control plane | 0.10 | 73 |
| NAT gateway | 0.05 | 38 + data |
| ALB | 0.03 | 20 |
| 2 × t3.small nodes | 0.05 | 35 |
| RDS db.t4g.micro (single-AZ) | 0.02 | 13 + storage |
| Secrets Manager, S3, CloudWatch | ~0 | 3-6 |
| **dev environment** | **≈ 0.25** | **≈ 180** |
| **prod (Multi-AZ RDS, 2 nodes)** | **≈ 0.27** | **≈ 195** |

**One dev environment left running 24/7 burns about $6/day, roughly your whole $200 in
a month.** The $5/day budget alert will catch it within about a day, but alerts lag,
so destroying at the end of every session is the only real control.

## Your realistic spend

| Pattern | Cost |
|---|---|
| 3-hour evening in dev (incl. ~30 min build) | ≈ $0.90 |
| 20 hours/week in dev | ≈ $20-22 / month |
| A qa + prod promotion demo evening (2 h each) | ≈ $1.10 extra |

That fits the $30 budget, and the $200 credit covers several months of learning.

## Why destroy/apply, not stop/start

The EKS control plane, NAT gateway and ALB have **no stop button**. They bill hourly
until deleted. Scaling nodes to zero still leaves about $0.18/hour of fixed cost.
Rebuilding is one command, and practicing it every day is the IaC skill itself.

Rebuild time is about 25-30 minutes, because platform (EKS) and data (RDS) run in
sequence. Start the build, then make coffee or review yesterday's notes.
(Speed-up idea for later: decouple RDS from the platform layer so the two can apply
in parallel. A good exercise in layer design.)

## Built-in guardrails

- **Budgets in bootstrap** (they survive every destroy): $30/month with alerts at
  $15/$24/$30 plus forecast, and a $5/day alert, all to marijatimovska@gmail.com.
- **Push to main deploys dev only.** qa/prod need a deliberate "Run workflow".
- **Clean destroys:** the ALB is Terraform-owned and nothing in-cluster creates AWS
  resources, so `destroy-all.sh` leaves no orphans.
- **Deterministic names:** secrets delete immediately (`recovery_window_in_days = 0`),
  so tomorrow's rebuild reuses the same names.

## Habits

- End every session with `./scripts/destroy-all.sh`.
- Never run this project and `aws-devops-lab` environments at the same time.
- Weekly: Billing → Cost Explorer, grouped by *Service* and by tag `Environment`
  (every resource is tagged with Project, Environment and Layer).
- After console experiments, look for orphans Terraform didn't create: unattached
  Elastic IPs, EBS volumes, load balancers.
