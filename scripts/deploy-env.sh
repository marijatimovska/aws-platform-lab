#!/usr/bin/env bash
# Apply every layer of an environment in dependency order, then sync static content.
#   ./scripts/deploy-env.sh dev [-auto-approve]
set -euo pipefail

ENV="${1:-dev}"
shift || true
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

for LAYER in network platform data observability; do
  echo ""
  echo "=== $ENV / $LAYER ==="
  "$ROOT_DIR/scripts/tf.sh" "$ENV" "$LAYER" apply "$@"
done

"$ROOT_DIR/scripts/deploy-static.sh" "$ENV"

# Fresh cluster after a destroy/apply cycle has no ArgoCD - reinstall it if this
# env's gitops has been rendered (rendered values are stable across rebuilds:
# role ARNs, bucket and secret names are deterministic).
if [[ -f "$ROOT_DIR/gitops/clusters/$ENV/root.yaml" ]]; then
  "$ROOT_DIR/scripts/bootstrap-gitops.sh" "$ENV"
else
  echo ""
  echo "Infra is up. FIRST TIME for $ENV: ./scripts/render-gitops.sh $ENV, commit + push, then ./scripts/bootstrap-gitops.sh $ENV"
fi
