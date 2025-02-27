# Docker Ollama

Below is a straightforward example of how you can build and run [Ollama](https://github.com/jmorganca/ollama) under Docker using Docker Compose. This setup:

- Clones and builds Ollama from source within a builder image (using Go and the required dependencies).  
- Copies the resulting `ollama` binary into a smaller runtime image (Ubuntu).  
- Exposes Ollama’s default gRPC / HTTP port (11434) so you can interact with the service from outside.  
- Mounts a local `models` folder so you can store and reuse your model files without having to rebuild the container.

> **Note**: Official Linux binaries or Docker images for Ollama may not be available yet, so you typically have to build from source as shown below. Make sure you have Docker and Docker Compose (or Docker Desktop) installed on your machine.

---

## 1. Directory Structure

You can use something like this:

```
my-ollama/
├── docker-compose.yml
├── Dockerfile
└── models/
```

- **docker-compose.yml**: Orchestrates building and running the Ollama container.  
- **Dockerfile**: Builds Ollama from source.  
- **models/**: Folder on your host to keep model files (e.g., LLaMA 2, etc.) so they persist across container restarts.

---

## 2. Example Dockerfile

Create a file named **Dockerfile** in your `my-ollama/` directory with the following contents:

```dockerfile
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
```

Explanation:

1. **Builder Stage**  
   - Uses the official Go image (1.20).  
   - Installs required system dependencies (cmake, clang, pkg-config, libssl-dev).  
   - Clones Ollama’s source code from GitHub.  
   - Compiles Ollama (`go build`) with the `full` tag.

2. **Runtime Stage**  
   - Copies the built `ollama` binary from the builder.  
   - Creates a folder to store model cache.  
   - Exposes port **11434**.  
   - Sets the default command to `ollama serve`, which starts the server.

---

## 3. Example docker-compose.yml

In your `my-ollama/` folder, create a **docker-compose.yml**:

```yaml
version: "3.8"

services:
  ollama:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: ollama
    ports:
      - "11434:11434"
    volumes:
      # Mount a local folder for your models/cache
      - ./models:/root/.ollama/models
    environment:
      # Set an env var so Ollama knows where to find models
      - OLLAMA_MODELS=/root/.ollama/models
      - OLLAMA_HOST=0.0.0.0
    # By default we run "ollama serve" from the Dockerfile CMD
    # If you want to override it, uncomment below:
    # command: ["ollama", "serve"]
```

Explanation:

- **build**: Uses the local Dockerfile in the current directory.  
- **ports**: Binds host port `11434` to container port `11434` for Ollama’s service.  
- **volumes**: Mounts your host `./models` directory to `/root/.cache/ollama` in the container (which is Ollama’s default cache location).  
- **environment**: Sets `OLLAMA_MODEL_PATH` so Ollama knows where to find models.

---

## 4. Bring Up the Service

From inside your `my-ollama/` folder, run:

```bash
docker-compose up --build -d
```

- **--build** forces a rebuild if you’ve changed the Dockerfile.  
- **-d** runs it in detached mode.  

Docker will:

1. Build the builder image to compile Ollama.  
2. Build the runtime image with the compiled binary.  
3. Start the container named `ollama`.  

> If everything succeeds, you’ll see a container named `ollama` running.

---

## 5. Testing Your Setup

Once the container is running, you can test Ollama with simple commands:

1. **Check container logs** (to see if it’s running properly):
   ```bash
   docker-compose logs -f ollama
   ```
2. **Exec into the container** (to run commands inside):
   ```bash
   docker exec -it ollama /bin/bash
   ```
   Then inside the container, you can run something like:
   ```bash
   ollama list
   ```
   or
   ```bash
   ollama pull llama2
   ```
   (Adjust for whichever model you need.)

3. **Use Ollama’s HTTP endpoint**:  
   By default, `ollama serve` also starts an HTTP/gRPC server on port **11434**. For example, you might do:
   ```bash
   curl -X POST -H "Content-Type: application/json" \
     -d '{"prompt":"Hello, how are you?"}' \
     http://localhost:11434/api/generate
   ```
   and see JSON output with the model’s response.

---

## 6. Stopping & Cleaning Up

- **Stop** the containers (without removing them):
  ```bash
  docker-compose stop
  ```
- **Remove** containers, volumes, and networks:
  ```bash
  docker-compose down
  ```
- **Remove** everything including the images you built:
  ```bash
  docker-compose down --rmi all
  ```

---

## 7. Customization Tips

- **CPU vs. GPU**: If you want to use GPU acceleration (and Ollama supports it for your platform), you’ll need to install CUDA or the appropriate GPU drivers in the Dockerfile, and run with `nvidia` support in Docker Compose.  
- **Apple Silicon**: Currently, Ollama works natively on Apple Silicon macOS, but Docker images for Apple Silicon can be more complex. You might need to cross-compile or rely on Rosetta. If you are on an M1/M2 Mac and encounter issues building or running, check the [Ollama GitHub issues](https://github.com/ollama/ollama/issues) for the latest details.  
- **Model Storage**: If you want a different directory for storing models, change the volume mount and/or set a different `OLLAMA_MODELS`.  

That’s it! With these steps, you’ll have a Docker-based Ollama server listening on port 11434. You can then pull (or copy in) models and interact with them via the CLI or HTTP.