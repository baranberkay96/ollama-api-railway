#!/bin/sh
# API gateway start (Railway): checks the API key and runs Caddy.
# No deploy-form value stops the deploy: a missing or unusable key locks the
# API with a random key nobody knows instead of opening it.
set -u

log() { echo "[railway-gateway] $*"; }
warn() { echo "[railway-gateway] WARNING: $*" >&2; }

port="${PORT:-8080}"
case "$port" in
'' | *[!0-9]*) warn "PORT='$port' is not a port number; using 8080"; port=8080 ;;
esac
PORT=$port

key=${OLLAMA_API_KEY:-}
case "$key" in
*[!A-Za-z0-9._~+/=-]*) bad="has characters other than A-Z a-z 0-9 . _ ~ + / = -" ;;
*) if [ "${#key}" -lt 24 ] || [ "${#key}" -gt 256 ]; then bad="is empty, shorter than 24 or longer than 256 characters"; else bad=""; fi ;;
esac
if [ -n "$bad" ]; then
	warn "OLLAMA_API_KEY $bad."
	warn "The API is LOCKED with a random key nobody knows. Set OLLAMA_API_KEY"
	warn "(24-256 characters: A-Z a-z 0-9 . _ ~ + / = -) on the API Gateway service and redeploy it."
	key=$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')
fi

upstream=${OLLAMA_UPSTREAM:-}
if [ -z "$upstream" ]; then
	warn "OLLAMA_UPSTREAM is empty; using ollama.railway.internal:11434"
	upstream=ollama.railway.internal:11434
fi

OLLAMA_API_KEY=$key
OLLAMA_UPSTREAM=$upstream
export PORT OLLAMA_API_KEY OLLAMA_UPSTREAM

log "API key check on; Ollama at $OLLAMA_UPSTREAM; port $PORT"
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
