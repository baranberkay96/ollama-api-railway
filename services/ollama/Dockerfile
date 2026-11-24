# syntax=docker/dockerfile:1
#
# CPU-only Ollama for Railway (private network; the API Gateway service in
# front of it checks the API key).
#
# The official image (ollama/ollama:0.40.17, amd64 3.4 GB compressed) is
# mostly GPU libraries (CUDA/ROCm) that Railway can never use, and it is close
# to the 4 GB image cap of Railway's Trial and Free plans. This build copies
# the ollama binary and its CPU libraries onto the same Ubuntu 24.04 base,
# which brings the image to a few hundred MB. To upgrade, replace the tag and
# digest of OLLAMA_IMAGE together and redeploy.
ARG OLLAMA_IMAGE=ollama/ollama:0.40.17@sha256:ccc42bcd3d5fcf7ab0d532b300382154e1a4da56fc666bdb313b78ebdd912754
ARG UBUNTU_IMAGE=ubuntu:noble-20261110.1@sha256:882e1e56091c9ffbc70c026ff5935fe85d3c91ad155917865ba2ffa23ede1560

FROM ${OLLAMA_IMAGE} AS ollama
# Drop the GPU backends; everything else (CPU backends, runners) stays.
RUN echo "ollama libraries before: $(du -sh /usr/lib/ollama | cut -f1)" \
 && ls /usr/lib/ollama \
 && rm -rf /usr/lib/ollama/cuda_* /usr/lib/ollama/rocm* /usr/lib/ollama/vulkan* /usr/lib/ollama/mlx_cuda* \
 && echo "ollama libraries after: $(du -sh /usr/lib/ollama | cut -f1)" \
 && ls /usr/lib/ollama

FROM ${UBUNTU_IMAGE}
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/*
COPY --from=ollama /usr/bin/ollama /usr/bin/ollama
COPY --from=ollama /usr/lib/ollama /usr/lib/ollama
COPY --chmod=0755 railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN ollama --version 2>/dev/null || true

ENV OLLAMA_HOST=[::]:11434 \
    PORT=11434
EXPOSE 11434
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
