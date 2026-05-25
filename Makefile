.PHONY: build build-example build-wasm pack publish

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

# Pack npm tarball (produces charnley-hello-wasm-*.tgz)
pack:
	npm pack

# Publish to npm (requires --otp if 2FA enabled: make publish OTP=123456)
publish:
	npm publish --access public $(if $(OTP),--otp $(OTP),)
