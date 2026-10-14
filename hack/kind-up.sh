#!/usr/bin/env bash
set -euo pipefail

cluster_name="${KIND_CLUSTER_NAME:-ai-grid-hub}"
export KIND_EXPERIMENTAL_PROVIDER="${KIND_EXPERIMENTAL_PROVIDER:-podman}"

if ! kind get clusters | grep -qx "$cluster_name"; then
  kind create cluster --name "$cluster_name" --wait 5m
fi

podman build -t localhost/ai-grid-backend:dev -f Containerfile .
kind load docker-image localhost/ai-grid-backend:dev --name "$cluster_name"

kubectl apply -f deploy/kind/ai-grid-backend.yaml
kubectl apply -f deploy/kind/keycloak.yaml
kubectl -n ai-grid rollout restart deployment/ai-grid-backend

echo "Kind cluster is ready. Install OCM with: clusteradm init --wait"
echo "Then apply sample resources with: kubectl apply -f deploy/kind/sample-managedclusters.yaml"
echo "Expose the backend with: kubectl -n ai-grid port-forward service/ai-grid-backend 8080:8080"
