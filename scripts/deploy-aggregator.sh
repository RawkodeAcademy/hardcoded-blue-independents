#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   scripts/deploy-aggregator.sh /absolute/path/to/kubeconfig [namespace]
# Env:
#   TTL (default: 24h)
#   PREFIX (default: text-analyzer)
#   PLATFORMS (default: linux/amd64,linux/arm64)
#   NAME (default: aggregator)  # deployment and service name
#
# Requires: docker (with buildx), kubectl

if [[ ${1:-} == "" ]]; then
  echo "ERROR: kubeconfig path argument is required" >&2
  exit 1
fi
KUBECONFIG_PATH=$1
NAMESPACE=${2:-textanalyzer}
NAME=${NAME:-aggregator}

if [[ ! -f "$KUBECONFIG_PATH" ]]; then
  echo "ERROR: kubeconfig '$KUBECONFIG_PATH' not found" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker CLI not found" >&2
  exit 1
fi
if ! docker buildx version >/dev/null 2>&1; then
  echo "ERROR: docker buildx not available. Enable Buildx (Docker Desktop) or run: \n  docker buildx create --use --name multi && docker buildx inspect --bootstrap" >&2
  exit 1
fi
if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl not found" >&2
  exit 1
fi

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

TTL=${TTL:-24h}
PREFIX=${PREFIX:-text-analyzer}
PLATFORMS=${PLATFORMS:-linux/amd64,linux/arm64}

# Random short suffix for ttl.sh tag uniqueness
random_suffix() {
  if command -v hexdump >/dev/null 2>&1; then
    hexdump -n3 -v -e '/1 "%02x"' /dev/urandom
  else
    dd if=/dev/urandom bs=3 count=1 2>/dev/null | od -An -v -tx1 | tr -d ' \n'
  fi
}
SUFFIX=$(random_suffix)
TAG="ttl.sh/${PREFIX}-${NAME}-${SUFFIX}:${TTL}"

echo "[deploy-aggregator] Building multi-arch image -> ${TAG} (platforms: ${PLATFORMS})" >&2

docker buildx build \
  --platform "${PLATFORMS}" \
  -f Dockerfile.aggregator \
  -t "${TAG}" \
  --push \
  .

# Show platforms for sanity
(docker buildx imagetools inspect "${TAG}" | sed -n '1,60p' >&2) || true

KUBECTL="kubectl --kubeconfig=${KUBECONFIG_PATH}"

# Ensure namespace exists
$KUBECTL get ns "$NAMESPACE" >/dev/null 2>&1 || $KUBECTL create namespace "$NAMESPACE"

# Update deployment image and wait for rollout
if $KUBECTL -n "$NAMESPACE" get deploy/"$NAME" >/dev/null 2>&1; then
  echo "[deploy-aggregator] Updating image on existing Deployment/$NAME ..." >&2
  $KUBECTL -n "$NAMESPACE" set image deploy/"$NAME" "$NAME"="${TAG}"
else
  echo "[deploy-aggregator] No existing Deployment/$NAME found in $NAMESPACE. You can create it via k8s manifests first." >&2
  exit 1
fi

$KUBECTL -n "$NAMESPACE" rollout status deploy/"$NAME" --timeout=180s

# Show service info if present
if $KUBECTL -n "$NAMESPACE" get svc/"$NAME" >/dev/null 2>&1; then
  $KUBECTL -n "$NAMESPACE" get svc/"$NAME" -o wide
else
  echo "[deploy-aggregator] Note: Service/$NAME not found in $NAMESPACE." >&2
fi

echo "[deploy-aggregator] Done. Image: ${TAG}" >&2
