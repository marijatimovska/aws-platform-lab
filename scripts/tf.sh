#!/usr/bin/env bash
# Layer-aware Terraform wrapper: one command per environment+layer, correct
# remote state every time.
#
#   ./scripts/tf.sh <env> <layer> <command> [extra args]
#
#   ./scripts/tf.sh dev network plan
#   ./scripts/tf.sh dev platform apply
#   ./scripts/tf.sh prod data destroy
#   ./scripts/tf.sh dev platform output -raw cluster_name
set -euo pipefail

ENV="${1:-}"
LAYER="${2:-}"
CMD="${3:-}"
shift 3 || true

PROJECT="${PROJECT:-platlab}"
REGION="${AWS_REGION:-eu-central-1}"

declare -A LAYER_DIRS=(
  [network]="10-network"
  [platform]="20-platform"
  [data]="30-data"
  [observability]="40-observability"
)

if [[ ! "$ENV" =~ ^(dev|qa|prod)$ ]] || [[ -z "${LAYER_DIRS[$LAYER]:-}" ]] || [[ -z "$CMD" ]]; then
  echo "Usage: $0 <dev|qa|prod> <network|platform|data|observability> <plan|apply|destroy|output|...> [args]"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LAYER_DIR="$ROOT_DIR/terraform/layers/${LAYER_DIRS[$LAYER]}"
VAR_FILE="$ROOT_DIR/terraform/environments/$ENV/$LAYER.tfvars"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
STATE_BUCKET="$PROJECT-tfstate-$ACCOUNT_ID"

echo ">> env=$ENV layer=$LAYER state=s3://$STATE_BUCKET/env/$ENV/$LAYER.tfstate" >&2

terraform -chdir="$LAYER_DIR" init -reconfigure -input=false \
  -backend-config="bucket=$STATE_BUCKET" \
  -backend-config="key=env/$ENV/$LAYER.tfstate" \
  -backend-config="region=$REGION" >/dev/null

case "$CMD" in
  init)
    echo "initialized." >&2
    ;;
  output|console|state|import|taint|untaint|refresh)
    terraform -chdir="$LAYER_DIR" "$CMD" "$@"
    ;;
  plan|apply|destroy)
    terraform -chdir="$LAYER_DIR" "$CMD" \
      -var-file="$VAR_FILE" \
      -var "environment=$ENV" \
      -var "project=$PROJECT" \
      -var "region=$REGION" \
      "$@"
    ;;
  *)
    terraform -chdir="$LAYER_DIR" "$CMD" "$@"
    ;;
esac
