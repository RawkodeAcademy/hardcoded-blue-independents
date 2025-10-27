**Overview**
- Kotlin/Ktor implementation of the text-analysis challenge.
- One reusable microservice binary (selected via `SERVICE` env var) exposes:
  - `GET /healthz` → `{ ok: true }`
  - `POST /op { text?, deps? }` → `{ key, value, cache_hit }`
  - `GET /debug/pprof/profile?seconds=30` → returns a JFR file (CPU profile)
- Aggregator (`POST /analyze { text }`) orchestrates calls and returns all fields plus `degraded`.

**Modules**
- `common`: Shared models, text ops, pprof helper (JFR-based)
- `service`: Reusable microservice. Select behavior with `SERVICE` env var.
- `aggregator`: Orchestrates service calls, handles degraded semantics.

**Supported Keys**
- `normalized`, `transliterated`, `slug`, `tokens` (array)
- `unique_words`, `bigram_count`, `char_count`, `unique_chars`
- `hash64` (xxhash64), `entropy`, `palindrome`

**Run (example ports)**
- Normalizer: `PORT=7001 SERVICE=normalized ./gradlew :service:run`
- Transliterator: `PORT=7002 SERVICE=transliterated ./gradlew :service:run`
- Slug: `PORT=7003 SERVICE=slug ./gradlew :service:run`
- Tokens: `PORT=7004 SERVICE=tokens ./gradlew :service:run`
- Unique words: `PORT=7005 SERVICE=unique_words ./gradlew :service:run`
- Bigram count: `PORT=7006 SERVICE=bigram_count ./gradlew :service:run`
- Char count: `PORT=7007 SERVICE=char_count ./gradlew :service:run`
- Unique chars: `PORT=7008 SERVICE=unique_chars ./gradlew :service:run`
- Hash64: `PORT=7009 SERVICE=hash64 ./gradlew :service:run`
- Entropy: `PORT=7010 SERVICE=entropy ./gradlew :service:run`
- Palindrome: `PORT=7011 SERVICE=palindrome ./gradlew :service:run`
- Aggregator: `PORT=7100 ./gradlew :aggregator:run`

The Aggregator default service URLs (env override-able):
`NORMALIZER_URL, TRANSLITERATOR_URL, SLUG_URL, TOKENS_URL, UNIQUE_WORDS_URL, BIGRAM_COUNT_URL, CHAR_COUNT_URL, UNIQUE_CHARS_URL, HASH64_URL, ENTROPY_URL, PALINDROME_URL`.
Defaults to `http://127.0.0.1:<port>/op` using the example ports above (7001…7011).

**API Examples**
- Analyze: `curl -s localhost:7100/analyze -H 'content-type: application/json' -d '{"text":"Ångström & co."}' | jq`.
- Service call: `curl -s localhost:7001/op -H 'content-type: application/json' -d '{"text":"Ångström"}'`.
- Health: `curl -s localhost:7001/healthz`.
- CPU profile (JFR): `curl -sLo profile.jfr 'http://localhost:7001/debug/pprof/profile?seconds=15'`.

**Notes on pprof**
- `/debug/pprof/profile` returns a JFR recording, not Go’s pprof proto. Many tools (JDK Mission Control, async-profiler, Parca via jfr2pprof) can use JFR directly or convert it. If you need native pprof output, we can integrate async-profiler and serve pprof; say the word.

**Docker Images (ttl.sh)**
- Build & push all service variants plus aggregator (default TTL 24h): `TTL=12h PREFIX=myteam bash scripts/publish-ttl.sh`
- Each service image sets `SERVICE` during build; override at runtime if needed: `docker run -e SERVICE=hash64 -e PORT=8080 <tag>`
- Example aggregator run: `docker run -e NORMALIZER_URL=http://normalizer:8080/op -p 8081:8080 <aggregator-tag>`
- Generated tags print at the end of the publish script; ttl.sh expires them automatically after the chosen TTL.



---

### Multi-arch builds (fix for exec format error)
Some clusters run on ARM64 nodes. If you build an AMD64-only image locally and deploy it to an ARM64 node, the container will fail with:

`exec /opt/aggregator/bin/aggregator: exec format error`

This repo now builds multi-architecture images (linux/amd64 and linux/arm64) using Docker Buildx.

Prerequisites:
- Docker with Buildx enabled (Docker Desktop or manual):
  - `docker buildx version`
  - If needed: `docker buildx create --use --name multi && docker buildx inspect --bootstrap`

Build & push all services + aggregator to ttl.sh as multi-arch:
```
TTL=24h PREFIX=myteam PLATFORMS=linux/amd64,linux/arm64 \
  bash scripts/publish-ttl.sh
```
This writes `images.env` and you can deploy with `scripts/deploy.sh`.

Quick path: rebuild and redeploy ONLY the aggregator as multi-arch, keeping the current Kubernetes objects:
```
KCFG=/Users/sondre/repos/cloudnativebergen/2025/blue-independents.kubeconfig
NS=blue-independents
TTL=24h PREFIX=blue-independents \
  bash scripts/deploy-aggregator.sh "$KCFG" "$NS"
```
The script will:
- Build and push a fresh multi-arch tag to ttl.sh
- Patch the Deployment image and wait for rollout
- Print the Service status

Verification:
```
kubectl --kubeconfig="$KCFG" -n "$NS" get deploy,po,svc
kubectl --kubeconfig="$KCFG" -n "$NS" logs deploy/aggregator --tail=50
```
You should no longer see the exec format error. If microservices aren’t deployed yet, `/analyze` may report `degraded=true` which is expected until they are running.
