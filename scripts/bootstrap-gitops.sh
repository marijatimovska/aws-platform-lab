#!/usr/bin/env bash
# One-time per environment: install ArgoCD and hand it the root Application.
# From then on, everything in-cluster is pulled from git by ArgoCD.
#   ./scripts/bootstrap-gitops.sh dev
# Prereqs: platform layer applied; render-gitops.sh output COMMITTED AND PUSHED
# (ArgoCD reads the repo, not your working copy).
set -euo pipefail

ENV="${1:-dev}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REGION="${AWS_REGION:-eu-central-1}"

ROOT_APP="$ROOT_DIR/gitops/clusters/$ENV/root.yaml"
if [[ ! -f "$ROOT_APP" ]]; then
  echo "ERROR: $ROOT_APP missing - run ./scripts/render-gitops.sh $ENV first." >&2
  exit 1
fi

CLUSTER="$("$ROOT_DIR/scripts/tf.sh" "$ENV" platform output -raw cluster_name)"
aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" >/dev/null

echo ">> installing ArgoCD" >&2
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  -f "$ROOT_DIR/gitops/bootstrap/argocd-values.yaml" \
  --wait --timeout 10m

echo ">> applying root application (app-of-apps)" >&2
kubectl apply -f "$ROOT_APP"

echo ""
echo "ArgoCD is reconciling gitops/clusters/$ENV from git."
echo "UI:       kubectl port-forward svc/argocd-server -n argocd 8080:443  ->  https://localhost:8080"
echo "Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "Watch:    kubectl get applications -n argocd"
