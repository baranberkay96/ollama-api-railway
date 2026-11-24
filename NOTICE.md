# NOTICE: Ollama API template

This is a community template. It is not made, endorsed or supported by Ollama, the model publishers or Railway.

## Components

| Component | Source | License | How it is used |
|---|---|---|---|
| Ollama 0.40.17 (`ollama/ollama:0.40.17@sha256:ccc42bcd3d5fcf7ab0d532b300382154e1a4da56fc666bdb313b78ebdd912754`) | https://github.com/ollama/ollama | MIT | `ollama` binary and CPU libraries copied unmodified from the official image; GPU backends left out |
| Ubuntu 24.04 (`ubuntu:noble-20261110.1@sha256:882e1e56091c9ffbc70c026ff5935fe85d3c91ad155917865ba2ffa23ede1560`), ca-certificates | https://hub.docker.com/_/ubuntu | Each package's own license | Base image of the Ollama service (same base as the official image) |
| Caddy 2.11.9 (`caddy:2.11.9-alpine@sha256:003a97808e781aa9f7e75cc2f43d34d461099031faf5e20faefb9f61126836f0`) | https://github.com/caddyserver/caddy | Apache-2.0 | Gateway |
| Models pulled at start: `qwen2.5:1.5b` (Qwen2.5-1.5B-Instruct, Apache-2.0), `nomic-embed-text:v1.5` (Apache-2.0) | https://ollama.com/library | Model licenses as published | Downloaded by the user's deployment from the Ollama registry; not redistributed by this template. Other models you pull have their own licenses. |

## Files written for this template

`services/gateway/*` and `services/ollama/Dockerfile` were written for this template; `services/ollama/railway-entrypoint.sh` is adapted from our own Odysseus template (thread sizing from the cgroup CPU quota). All are offered under the MIT License, as is the documentation.

## Upstream files checked

- ollama v0.40.17 image config (entrypoint `/bin/ollama serve`, `OLLAMA_HOST`, `/usr/lib/ollama` layout) and release list (2026-11-24).
- Ollama docs: OpenAI compatibility (`/v1/chat/completions`, `/v1/embeddings`, `/v1/models`), environment variables (`OLLAMA_KEEP_ALIVE`, `OLLAMA_CONTEXT_LENGTH`, `OLLAMA_KV_CACHE_TYPE`, `OLLAMA_ORIGINS`).
- Ollama registry manifests for the default models (sizes).

## Market templates

The Ollama templates on the Railway marketplace (`T9CQ5w`, `ollama-openwebui-or-self-host-your-own-c`, `ollama-or-self-host-open-source-llms`) were reviewed for features only. No files or text were copied.
