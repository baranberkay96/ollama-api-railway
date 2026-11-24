# Deploy and Host Ollama API with Railway

Your own LLM API on Railway: Ollama runs open models on CPU on the private network, and a small gateway in front of it exposes an OpenAI-compatible API on a public HTTPS domain that only answers requests with your API key. A 1.5B chat model and an embedding model are pulled on the first start.

## About Hosting Ollama API

Ollama serves open-weight models (Qwen, Llama, Gemma, Mistral and many more) through its native API and an OpenAI-compatible `/v1` API, but it has no authentication of its own, so it must never be exposed directly. This community template keeps Ollama private and puts a Caddy gateway in front that checks `Authorization: Bearer {key}` (or `x-api-key`) on every request and streams tokens as they are generated. Ollama is built CPU-only (the GPU libraries are dropped, so the image is small), its thread pool is sized to the service's CPU quota so generation does not stall on Railway's shared hosts, models live on a volume, and missing models from `OLLAMA_PULL_MODELS` are pulled at start.

## Common Use Cases

- A private OpenAI-compatible endpoint for scripts, agents and apps (OpenAI SDKs, LangChain, LlamaIndex, n8n)
- Embeddings for RAG pipelines without sending data to a third party
- Small, cheap models for classification, extraction and summarisation jobs
- A backend for chat UIs that speak the OpenAI API

## Dependencies for Ollama API Hosting

- Ollama (CPU build of the official release) with a volume for models
- API Gateway (Caddy 2.11) with a public domain
- No external API keys

### Deployment Dependencies

- [Ollama documentation](https://docs.ollama.com/)
- [Ollama OpenAI compatibility](https://docs.ollama.com/api/openai-compatibility)
- [Ollama model library](https://ollama.com/library)
- [Ollama on GitHub](https://github.com/ollama/ollama)
- [Caddy documentation](https://caddyserver.com/docs/)

### Implementation Details

| Service | What runs inside | Volume | Port |
|---|---|---|---|
| API Gateway | Caddy 2.11.9: API-key check, streaming reverse proxy | none | 8080, public domain |
| Ollama | Ollama 0.40.17 (CPU), models `qwen2.5:1.5b` and `nomic-embed-text:v1.5` | `/root/.ollama` (models) | 11434, private |

**First request**

Your key is `OLLAMA_API_KEY` on the API Gateway service (Variables tab); the base URL is in `API_BASE_URL`. The first start downloads about 1.3 GB of models; the Ollama log says `model ... ready` when done.

```bash
curl https://{your-domain}/v1/chat/completions \
  -H "Authorization: Bearer {your-key}" -H "Content-Type: application/json" \
  -d '{"model": "qwen2.5:1.5b", "messages": [{"role": "user", "content": "Say hello"}]}'
```

With the OpenAI Python SDK: `OpenAI(base_url="https://{your-domain}/v1", api_key="{your-key}")`. Embeddings: `POST /v1/embeddings` with `"model": "nomic-embed-text:v1.5"`. `GET /v1/models` lists the installed models. Ollama's native API (`/api/chat`, `/api/generate`, `/api/pull`, ...) works under the same key. Requests without the key get 401.

**Models**

Change `OLLAMA_PULL_MODELS` on the Ollama service (comma-separated names from the Ollama library) and redeploy; missing models are pulled at start, and models already on the volume stay. You can also pull through the API: `POST /api/pull` with `{"model": "llama3.2:3b"}`. Delete with `DELETE /api/delete`. Each model needs roughly its download size in RAM while loaded, plus context memory.

**Performance on CPU**

Railway services run on CPU. Small models (0.5–3B parameters, 4-bit) answer in seconds; 7–8B models work but slowly. The inference thread count follows the service's CPU limit (at most 8; `OLLAMA_NUM_THREAD` overrides). Models stay loaded for `OLLAMA_KEEP_ALIVE` (15 minutes) after the last request; the first request after that loads the model again. Thinking models (for example qwen3) produce long hidden reasoning before answering on the OpenAI endpoint, which is slow on CPU; prefer non-thinking models for this API.

**Security**

Only the gateway is public. Keep the API key secret: anyone with it can use your compute and pull or delete models. To rotate it, change `OLLAMA_API_KEY` and redeploy the gateway. A key that is empty, shorter than 24 characters or uses other characters than `A-Z a-z 0-9 . _ ~ + / = -` locks the API (random key, warning in the log) instead of opening it. Authorization headers are removed from the gateway's access log.

**Scaling and versions**

Give the Ollama service more RAM and vCPUs for larger models (Hobby or Pro). One Ollama replica holds the models on its volume. Versions are pinned in the Dockerfiles (`OLLAMA_IMAGE` tag and digest, Caddy tag and digest); change them there to upgrade.

**Resources**

Measured on Railway: Ollama idles at about 30 MB with no model loaded and about 1.3 GB with the chat and embedding models loaded; the gateway uses about 15 MB. Loaded models need more than the Trial plan's 1 GB per service: use Hobby or higher. Cost while models are loaded is roughly $15–25/month in RAM plus the CPU your requests use; with short keep-alive times most of it disappears when the API is idle.

### Why Deploy Ollama API on Railway?

Railway keeps Ollama on a private network with a persistent model volume and gives the gateway an HTTPS domain, so you get your own authenticated, OpenAI-compatible LLM endpoint in one deploy, billed only for the RAM and CPU it uses. This is a community template, not affiliated with Ollama or the model publishers.
