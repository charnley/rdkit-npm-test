# Build example WASM module from src/hello.cpp
#
# Usage (from repo root):
#
#   DOCKER_BUILDKIT=1 docker build \
#     -f docker/build-example.Dockerfile \
#     --output type=local,dest=dist \
#     .

# ---------------------------------------------------------------------------
# Stage 1: compile
# ---------------------------------------------------------------------------
FROM emscripten/emsdk:latest AS build-stage

WORKDIR /src
COPY src/hello.cpp .

RUN emcc hello.cpp \
    --bind \
    --emit-tsd hello.d.ts \
    -s MODULARIZE=1 \
    -s EXPORT_NAME='initHelloModule' \
    -s ALLOW_MEMORY_GROWTH=1 \
    -O3 \
    -o hello.js



# ---------------------------------------------------------------------------
# Stage 2: export artifacts only (requires BuildKit --output)
# ---------------------------------------------------------------------------
FROM scratch AS export-stage
COPY --from=build-stage /src/hello.js /
COPY --from=build-stage /src/hello.wasm /
