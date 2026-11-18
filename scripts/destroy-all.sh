#!/usr/bin/env bash
# End-of-day cost killer: destroy every environment, layers in reverse order.
# Bootstrap (state bucket, budgets, OIDC role) is intentionally left alone.
# Everything in-cluster (ArgoCD, apps) dies with the cluster; the ALB is
# Terraform-owned - no orphaned load balancers.
#   ./scripts/destroy-all.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

for ENV in prod qa dev; do
  for LAYER in observability data platform network; do
    echo ""
    echo "=== destroying $ENV / $LAYER ==="
    "$ROOT_DIR/scripts/tf.sh" "$ENV" "$LAYER" destroy -auto-approve \
      || echo "(skip: $ENV/$LAYER not deployed or already empty)"
  done
done

echo ""
echo "All environments destroyed. Bootstrap/budgets remain. Nothing is billing by the hour."
