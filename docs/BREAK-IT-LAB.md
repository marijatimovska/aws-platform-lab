# Break-It Lab

Break it, observe, diagnose, fix, then write a short post-mortem (what happened, how
you detected it, root cause, fix, prevention) in `docs/postmortems/`. A folder of
those is strong interview evidence.

Do these in dev unless noted. They're grouped by what they teach.

## A. Kubernetes fundamentals

1. **Kill pods.** `kubectl delete pod -l app.kubernetes.io/name=webapp`. Watch the ReplicaSet and PDB keep the site up.
2. **Drain a node.** `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data`. This is the real patching workflow.
3. **OOMKill.** Set `resources.limits.memory: 16Mi` in `values-dev.yaml`, push, and read `kubectl describe pod`.
4. **Break the Service selector.** Patch it to a wrong label. ALB targets go unhealthy, you get 502s and an alarm email. Trace the full path from the ALB to the pod.
5. **CoreDNS outage.** `kubectl scale deploy coredns -n kube-system --replicas=0`. It's always DNS.
6. **Load test both scaling layers.** Run busybox `wget` loops against `webapp.default.svc`. The HPA adds pods at 70%, then the node CPU alarm adds a node.

## B. GitOps (ArgoCD)

7. **Self-heal.** `kubectl scale deploy webapp --replicas=1`, or edit the Deployment by hand. ArgoCD reverts it within seconds. Explain why `selfHeal: true` matters.
8. **Bad commit + rollback.** Push a nonexistent image tag. The rollout sticks at ImagePullBackOff while old pods keep serving. Fix it with `git revert`, not kubectl.
9. **Prune.** Delete `gitops/clusters/dev/metrics-server.yaml` and push. ArgoCD removes it from the cluster and the HPA goes `<unknown>`. Restore it.
10. **Out-of-band drift vs pipeline.** Change something with `helm upgrade` by hand and watch ArgoCD fight you. This is why one tool must own each layer.

## C. Secrets & IAM

11. **Break IRSA.** Put a wrong role ARN in `gitops/clusters/dev/external-secrets.yaml`. ExternalSecret shows `SecretSyncError`. Find it with `kubectl describe externalsecret` and the ESO pod logs.
12. **Rotate the secret.** Change a value in Secrets Manager, force-refresh the ExternalSecret (`kubectl annotate externalsecret webapp-db force-sync=$(date +%s) --overwrite`), and notice pods don't see it until restarted. Discuss reloader patterns.
13. **Least privilege.** Replace the CI role's AdministratorAccess with a scoped policy, iterating on `AccessDenied` errors in CI until green.

## D. Terraform & layers

14. **Destroy in the wrong order.** `./scripts/tf.sh dev network destroy` while platform still exists. Watch it fail with `DependencyViolation`, and explain why layer ordering exists.
15. **State lock.** Run two applies on the same layer at once. Read the lock error and learn when `force-unlock` is (and isn't) safe.
16. **Drift.** Delete an alarm in the console, run the *Drift detection* workflow, and reconcile.
17. **State surgery.** Rename a resource in code, then use a `moved {}` block (or `terraform state mv`) so nothing is destroyed and recreated.
18. **Module change ripple.** Change a module output. Which layers need re-planning? Fix the downstream layer that breaks.

## E. Resilience (deploy prod for these)

19. **AZ outage.** Terminate every node in one AZ. Pods are zone-spread and the ALB spans both AZs, so the site stays up.
20. **RDS failover.** `aws rds reboot-db-instance --db-instance-identifier platlab-prod-db --force-failover`. The endpoint DNS stays the same.

## Upgrades when you outgrow the lab

- **Pin chart versions** in `gitops/templates/` (replace `"*"`) and add Renovate.
- **Per-env promotion:** point prod's Applications at a release tag instead of `main`.
- **Karpenter** instead of CloudWatch node-scaling alarms.
- **AWS Load Balancer Controller + Ingress + ExternalDNS + ACM (HTTPS).** Compare with the Terraform-owned ALB pattern.
- **VPC CNI prefix delegation**, to raise the per-node pod limit so dev fits on one node.
- **Your own app image:** Dockerfile, ECR, a CI build/scan (Trivy)/push, and ArgoCD Image Updater.
- **Observability:** kube-prometheus-stack via ArgoCD (needs t3.medium), or AWS Managed Prometheus + Grafana.
- **Kyverno policies**, plus NetworkPolicies isolating the webapp namespace.
- **Checkov hard-fail** with reviewed skip annotations.
- **Multi-account** with AWS Organizations: same layers, an account per env.
- **Terragrunt**, to remove the repeated backend/provider blocks across layers.
