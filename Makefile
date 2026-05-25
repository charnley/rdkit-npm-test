.PHONY: build build-example build-wasm

# Build example WASM module (hello.cpp → dist/)
build: build-example

build-example:
	DOCKER_BUILDKIT=1 docker build \
		-f docker/build-example.Dockerfile \
		--output type=local,dest=dist \
		.

# Build RDKit WASM (run from rdkit repo root, three levels above)
build-wasm:
	DOCKER_BUILDKIT=1 docker build \
		-f docker/build-wasm.Dockerfile \
		--output type=local,dest=dist \
		.
