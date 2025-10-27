#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   scripts/deploy.sh /absolute/path/to/kubeconfig [namespace]
# Env:
#   TTL (default: 24h)
#   PREFIX (default: text-analyzer)
#   OUT_ENV (default: images.env)
#   DRY_RUN=true  # build/push images but skip kubectl apply (or skip both if you stop earlier)
#
# Requires: docker, kubectl, envsubst (from gettext) or perl for simple variable substitution.

if [[ ${1:-} == "" ]]; then
  echo "ERROR: kubeconfig path argument is required" >&2
  exit 1
fi
KUBECONFIG_PATH=$1
NAMESPACE=${2:-textanalyzer}

if [[ ! -f "$KUBECONFIG_PATH" ]]; then
  echo "ERROR: kubeconfig '$KUBECONFIG_PATH' not found" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker CLI not found" >&2
  exit 1
fi
if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl not found" >&2
  exit 1
fi

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

# 1) Build & push all images to ttl.sh
OUT_ENV=${OUT_ENV:-images.env}
TTL=${TTL:-24h}
PREFIX=${PREFIX:-text-analyzer}
export OUT_ENV TTL PREFIX

echo "[deploy] Building and pushing images to ttl.sh (TTL=$TTL, PREFIX=$PREFIX) ..." >&2
bash scripts/publish-ttl.sh

if [[ ! -f "$OUT_ENV" ]]; then
  echo "ERROR: expected $OUT_ENV to be created by publish-ttl.sh" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$OUT_ENV"

# Required vars from publish file
REQ_VARS=(
  IMAGE_NORMALIZED IMAGE_TRANSLITERATED IMAGE_SLUG IMAGE_TOKENS IMAGE_UNIQUE_WORDS
  IMAGE_BIGRAM_COUNT IMAGE_CHAR_COUNT IMAGE_UNIQUE_CHARS IMAGE_HASH64 IMAGE_ENTROPY IMAGE_PALINDROME
  IMAGE_AGGREGATOR
)
for v in "${REQ_VARS[@]}"; do
  if [[ -z "${!v:-}" ]]; then
    echo "ERROR: variable $v not found; check $OUT_ENV" >&2
    exit 1
  fi
  export "$v"
done
export NAMESPACE

# 2) Render k8s manifests
MANIFEST_TPL="k8s/app.yaml.tpl"
MANIFEST_OUT="k8s/app.yaml"

render_with_envsubst() {
  if command -v envsubst >/dev/null 2>&1; then
    envsubst < "$MANIFEST_TPL" > "$MANIFEST_OUT"
  else
    # Minimal perl fallback for ${VAR} only
    perl -pe 's/\$\{(\w+)\}/$ENV{$1}//g' "$MANIFEST_TPL" > "$MANIFEST_OUT"
  fi
}

echo "[deploy] Rendering manifests to $MANIFEST_OUT ..." >&2
render_with_envsubst

if [[ ${DRY_RUN:-} == "true" ]]; then
  echo "[deploy] DRY_RUN set; skipping kubectl apply. Manifests at $MANIFEST_OUT" >&2
  exit 0
fi

# 3) Apply manifests
KUBECTL="kubectl --kubeconfig=$KUBECONFIG_PATH"

# Create namespace if not exist
$KUBECTL get ns "$NAMESPACE" >/dev/null 2>&1 || $KUBECTL create namespace "$NAMESPACE"

echo "[deploy] Applying manifests ..." >&2
$KUBECTL apply -f "$MANIFEST_OUT"

echo "[deploy] Waiting for rollouts ..." >&2
for name in \
  normalized transliterated slug tokens unique-words bigram-count char-count unique-chars hash64 entropy palindrome aggregator; do
  $KUBECTL -n "$NAMESPACE" rollout status deploy/"$name" --timeout=180s
 done

echo "[deploy] Services available:" >&2
$KUBECTL -n "$NAMESPACE" get svc -o wide

echo "[deploy] Done. Aggregator service: aggregator.$NAMESPACE.svc.cluster.local:8080" >&2
