#!/usr/bin/env bash
set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "docker CLI not found" >&2
  exit 1
fi

TTL=${TTL:-24h}
PREFIX=${PREFIX:-text-analyzer}
SERVICES=(
  normalized
  transliterated
  slug
  tokens
  unique_words
  bigram_count
  char_count
  unique_chars
  hash64
  entropy
  palindrome
)

random_suffix() {
  if command -v hexdump >/dev/null 2>&1; then
    hexdump -n3 -v -e '/1 "%02x"' /dev/urandom
  else
    dd if=/dev/urandom bs=3 count=1 2>/dev/null | od -An -v -tx1 | tr -d ' \n'
  fi
}

SUFFIX=$(random_suffix)

declare -A IMAGE_TAGS

for svc in "${SERVICES[@]}"; do
  tag="ttl.sh/${PREFIX}-${svc}-${SUFFIX}:${TTL}"
  echo "\nBuilding service image for ${svc} -> ${tag}"
  docker build \
    --build-arg SERVICE_NAME="${svc}" \
    -f Dockerfile.service \
    -t "${tag}" \
    .
  docker push "${tag}"
  IMAGE_TAGS["${svc}"]=${tag}
done

agg_tag="ttl.sh/${PREFIX}-aggregator-${SUFFIX}:${TTL}"
echo "\nBuilding aggregator image -> ${agg_tag}"
docker build \
  -f Dockerfile.aggregator \
  -t "${agg_tag}" \
  .
docker push "${agg_tag}"

echo "\nPushed images:" >&2
for svc in "${SERVICES[@]}"; do
  printf '%-14s %s\n' "${svc}:" "${IMAGE_TAGS[${svc}]}"
done
printf '%-14s %s\n' "aggregator:" "${agg_tag}"
