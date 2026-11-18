#!/usr/bin/env bash
# Render gitops/templates/ -> gitops/clusters/<env>/ from Terraform outputs.
# Commit the result: that commit is what ArgoCD deploys.
#   ./scripts/render-gitops.sh dev
set -euo pipefail

ENV="${1:-dev}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REGION="${AWS_REGION:-eu-central-1}"
OUT_DIR="$ROOT_DIR/gitops/clusters/$ENV"

# Repo URL: explicit env var wins; otherwise derived from git remote.
REPO_URL="${GITOPS_REPO_URL:-$(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null || true)}"
if [[ -z "$REPO_URL" ]]; then
  echo "ERROR: set GITOPS_REPO_URL or add a git remote named origin." >&2
  exit 1
fi
# normalize git@github.com:user/repo.git -> https://github.com/user/repo.git
REPO_URL="${REPO_URL/git@github.com:/https:\/\/github.com\/}"

echo ">> reading terraform outputs ($ENV)" >&2
ESO_ROLE_ARN="$("$ROOT_DIR/scripts/tf.sh" "$ENV" data output -raw external_secrets_irsa_role_arn)"
WEBAPP_ROLE_ARN="$("$ROOT_DIR/scripts/tf.sh" "$ENV" data output -raw webapp_irsa_role_arn)"
DB_SECRET_NAME="$("$ROOT_DIR/scripts/tf.sh" "$ENV" data output -raw db_secret_name)"
STATIC_URL="$("$ROOT_DIR/scripts/tf.sh" "$ENV" data output -raw static_site_url)"

render() { # render <template> <dest>
  sed -e "s|__ENV__|$ENV|g" \
      -e "s|__REGION__|$REGION|g" \
      -e "s|__REPO_URL__|$REPO_URL|g" \
      -e "s|__ESO_ROLE_ARN__|$ESO_ROLE_ARN|g" \
      -e "s|__WEBAPP_ROLE_ARN__|$WEBAPP_ROLE_ARN|g" \
      -e "s|__DB_SECRET_NAME__|$DB_SECRET_NAME|g" \
      -e "s|__STATIC_URL__|$STATIC_URL|g" \
      "$1" > "$2"
}

mkdir -p "$OUT_DIR/eso-config"
for t in "$ROOT_DIR"/gitops/templates/*.tmpl.yaml; do
  render "$t" "$OUT_DIR/$(basename "${t%.tmpl.yaml}").yaml"
done
for t in "$ROOT_DIR"/gitops/templates/eso-config/*.tmpl.yaml; do
  render "$t" "$OUT_DIR/eso-config/$(basename "${t%.tmpl.yaml}").yaml"
done
rm -f "$OUT_DIR/.gitkeep"

echo ">> rendered to gitops/clusters/$ENV/"
echo ">> review, then: git add gitops/clusters/$ENV && git commit -m 'Render gitops ($ENV)' && git push"
