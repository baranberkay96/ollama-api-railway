# TEMPLATE: Ollama API (OpenAI-Compatible, API Key)

Composer spec. `template.json` is the machine-readable copy.

## Services

| Field | API Gateway | Ollama |
|---|---|---|
| Source | repo `baranberkay96/ollama-api-railway`, root `/services/gateway` | same repo, root `/services/ollama` |
| Base | `caddy:2.11.9-alpine@sha256:003a9780…` | binary + CPU libs from `ollama/ollama:0.40.17@sha256:ccc42bcd…` (2026-11-21) on `ubuntu:noble-20261110.1@sha256:882e1e56…` |
| Public domain | yes, 8080 | none |
| Healthcheck | `/healthz` (no key), 300 s | `/` on 11434, 300 s |
| Restart | ALWAYS | ALWAYS |
| Volume | none | `/root/.ollama` |

Gateway variables: `OLLAMA_API_KEY` (secret 48), `API_BASE_URL` (informational), `OLLAMA_UPSTREAM` (`${{Ollama.RAILWAY_PRIVATE_DOMAIN}}:11434`), `PORT`.
Ollama variables: `OLLAMA_PULL_MODELS` (qwen2.5:1.5b,nomic-embed-text:v1.5), `OLLAMA_NUM_THREAD`, `OLLAMA_CONTEXT_LENGTH` (8192), `OLLAMA_KEEP_ALIVE` (15m), `OLLAMA_MAX_LOADED_MODELS` (2), `OLLAMA_NUM_PARALLEL` (1), `OLLAMA_FLASH_ATTENTION` (1), `OLLAMA_KV_CACHE_TYPE` (q8_0), `OLLAMA_ORIGINS` (*), `OLLAMA_HOST` ([::]:11434), `PORT` (11434). No required inputs.

## Design

- Gateway: Caddy matchers `Authorization: Bearer {key}` or `X-Api-Key: {key}` → strip both headers → `reverse_proxy` with `flush_interval -1`; CORS preflight passes through; everything else 401 with an OpenAI-style JSON error. Start script locks the API with a random key on an empty/short/odd key (8.29). Caddyfile validated at build time. Access log with auth headers deleted.
- Ollama: CPU-only image (GPU backends removed; official image is 3.4 GB compressed, close to the 4 GB Trial cap, 8.33). Entry script from our Odysseus package: threads = cgroup CPU quota capped at 8, exported as `LLAMA_ARG_THREADS` (8.15); serve first, then pull missing models (names validated).
- Default chat model `qwen2.5:1.5b` (Apache-2.0, non-thinking, tool calling): thinking models are slow on CPU and Ollama's `/v1` ignores `think: false` (8.15).

## Improvements over market templates

- Market Ollama templates expose Ollama with no authentication (one publishes port 11434 on a public domain), use `ollama/ollama` unpinned (`latest`), pull no model, have no healthcheck and let llama.cpp start one thread per host core. This one adds an API-key gateway, pinned versions, a slim CPU image, thread sizing, preloaded chat + embedding models and healthchecks.

## Resources

| Service | Idle RAM | Typical RAM | CPU |
|---|---|---|---|
| API Gateway | ≈15 MB (measured) | 20–40 MB | ≈0 |
| Ollama | ≈30 MB no model loaded; ≈1.3 GB with both models loaded (measured) | 1.5–6 GB depending on models | up to 8 vCPU while generating |

Estimated: $1–3/month idle with models unloaded, $15–25/month while models stay loaded, plus CPU per request. Minimum plan: Hobby (loaded models exceed Trial's 1 GB).

## Verification checklist

- Gateway `/healthz` 200; `/v1/models` without key 401, with key 200 listing both models.
- `/v1/chat/completions` (non-streaming and `stream: true`) answers; `/v1/embeddings` returns vectors.
- Ollama log: thread count from the cgroup quota, both models pulled; redeploy keeps the models.
- `OLLAMA_API_KEY=abc` → gateway SUCCESS, every request 401, log warning.

## Open questions

- Generation speed depends on the host's CPU share; measured numbers are in the round-13 report.
