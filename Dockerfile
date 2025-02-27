# ------------------------------------------------------
# 1) Builder stage: build Ollama from source
# ------------------------------------------------------
    FROM golang:1.24 AS builder

    # Install dependencies needed to build Ollama (including git!)
    RUN apt-get update && apt-get install -y \
        git \
        cmake \
        clang \
        pkg-config \
        libssl-dev \
        && rm -rf /var/lib/apt/lists/*
    
    WORKDIR /app
    
    # Clone the Ollama repo into /app/ollama
    # This should contain folders like /app/ollama/cmd/ollama
    RUN git clone --depth 1 https://github.com/ollama/ollama.git ollama
    
    # Just to confirm the cloned structure
    RUN ls -l /app
    RUN ls -R /app/ollama
    
    # Switch to the ollama folder
    WORKDIR /app/ollama
    
    # Build the Ollama binary with "full" features from the root module
    # (This should pick up cmd/ollama/main.go)
    RUN go build -tags full -o /ollama .
    
    # ------------------------------------------------------
    # 2) Runtime stage: copy Ollama binary into a minimal image
    # ------------------------------------------------------
    FROM ubuntu:22.04 AS runtime
    
    # Ensure we have CA certificates installed and updated
    RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && update-ca-certificates

    # Copy the compiled ollama binary from the builder stage
    COPY --from=builder /ollama /usr/local/bin/ollama
    
    # Create a directory for model caching
    RUN mkdir -p /root/.ollama/models
    
    # Expose Ollama’s default port (11434)
    EXPOSE 11434
    
    # By default, run Ollama in server mode
    CMD ["ollama", "serve"]
    