#!/usr/bin/env bash
# Sync app-static/ to the environment's S3 static-content bucket.
#   ./scripts/deploy-static.sh dev
set -euo pipefail

ENV="${1:-dev}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

BUCKET="$("$ROOT_DIR/scripts/tf.sh" "$ENV" data output -raw static_bucket)"
URL="$("$ROOT_DIR/scripts/tf.sh" "$ENV" data output -raw static_site_url)"

echo ">> syncing app-static/ -> s3://$BUCKET"
aws s3 sync "$ROOT_DIR/app-static/" "s3://$BUCKET/" --delete
echo ">> done: $URL"
