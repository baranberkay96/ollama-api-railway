#!/bin/bash
# CPU Ollama on Railway, behind the API Gateway service.
#
# 1. Sizes the inference thread pool: the service's CPU quota, at most 8
#    (OLLAMA_NUM_THREAD overrides). Ollama's llama.cpp runner otherwise starts
#    one thread per visible core (48 on Railway), far more than the CPU time
#    it gets, and generation stalls almost completely. The count is exported as
#    LLAMA_ARG_THREADS, which Ollama passes to every runner it starts, so it
#    applies to every model, including ones pulled later.
# 2. Runs "ollama serve" and pulls OLLAMA_PULL_MODELS that are missing.
#    The API serves (and the healthcheck passes) while models download.
set -uo pipefail

CGROUP_ROOT=/sys/fs/cgroup
PROC_CGROUP=/proc/self/cgroup
# Upper bound for the automatic thread count. Railway shows up to 48 CPUs
# per container; on shared hosts llama.cpp's spin-waiting threads degrade
# sharply when they outnumber the CPU time actually granted, and a 1-4B model
# gains little beyond 8 threads. OLLAMA_NUM_THREAD can set any value.
AUTO_THREAD_CAP=8

log() { echo "[railway] $*"; }

# floor(quota/period) of the tightest CPU quota visible to this container
# (cgroup v2 cpu.max of the own cgroup and its visible ancestors, then
# cgroup v1 cfs quota). Prints nothing when every level is unlimited.
cgroup_cpu_limit() {
    local best="" quota period dir rel d

    consider() {
        [[ "$1" =~ ^[0-9]+$ && "$2" =~ ^[0-9]+$ ]] || return 0
        (( $2 > 0 )) || return 0
        local n=$(( $1 / $2 ))
        (( n < 1 )) && n=1
        if [[ -z "$best" ]] || (( n < best )); then best=$n; fi
    }

    if [[ -r "$CGROUP_ROOT/cgroup.controllers" ]]; then
        rel="$(awk -F: '$1 == "0" { print $3; exit }' "$PROC_CGROUP" 2>/dev/null)"
        dir="$CGROUP_ROOT${rel%/}"
        while [[ "$dir" == "$CGROUP_ROOT"* ]]; do
            if [[ -r "$dir/cpu.max" ]]; then
                read -r quota period < "$dir/cpu.max" && consider "$quota" "$period"
            fi
            [[ "$dir" == "$CGROUP_ROOT" ]] && break
            dir="$(dirname "$dir")"
        done
    fi
    for d in "$CGROUP_ROOT/cpu" "$CGROUP_ROOT/cpu,cpuacct" "$CGROUP_ROOT/cpuacct,cpu"; do
        if [[ -r "$d/cpu.cfs_quota_us" && -r "$d/cpu.cfs_period_us" ]]; then
            consider "$(cat "$d/cpu.cfs_quota_us")" "$(cat "$d/cpu.cfs_period_us")"
        fi
    done
    [[ -n "$best" ]] && echo "$best"
    return 0
}

# Prints "<threads> <source>".
resolve_threads() {
    local n source
    if [[ "${OLLAMA_NUM_THREAD:-}" =~ ^[1-9][0-9]*$ ]]; then
        echo "$OLLAMA_NUM_THREAD OLLAMA_NUM_THREAD"
        return
    fi
    n="$(cgroup_cpu_limit)"
    if [[ -n "$n" ]]; then
        source="cgroup-cpu-quota=$n"
    else
        n="$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
        source="no-quota-visible,nproc=$n"
    fi
    if (( n > AUTO_THREAD_CAP )); then
        echo "$AUTO_THREAD_CAP $source,capped"
    else
        echo "$n $source"
    fi
}

read -r THREADS THREAD_SOURCE < <(resolve_threads)
export LLAMA_ARG_THREADS="$THREADS"
log "inference threads: $THREADS (source: $THREAD_SOURCE)"

/usr/bin/ollama serve &
server_pid=$!
trap 'kill -TERM "$server_pid" 2>/dev/null; wait "$server_pid"; exit $?' TERM INT

client() { OLLAMA_HOST=127.0.0.1:11434 /usr/bin/ollama "$@"; }

for _ in $(seq 1 120); do
    client list >/dev/null 2>&1 && break
    sleep 1
done

pull_models() {
    local model
    for model in ${OLLAMA_PULL_MODELS//,/ }; do
        if [[ ! "$model" =~ ^[A-Za-z0-9][A-Za-z0-9._/:-]{0,199}$ ]]; then
            log "WARNING: '$model' is not a model name; skipped"
            continue
        fi
        if client show "$model" >/dev/null 2>&1; then
            log "model $model already present"
        else
            log "pulling $model"
            if client pull "$model" >/dev/null 2>&1; then
                log "model $model ready"
            else
                log "WARNING: pull of $model failed (unknown name or network); redeploy to retry"
            fi
        fi
    done
    log "models on the volume: $(client list 2>/dev/null | awk 'NR>1 {printf "%s ", $1}')"
}

pull_models

wait "$server_pid"
