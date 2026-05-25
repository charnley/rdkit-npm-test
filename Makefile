.PHONY: build build-example build-wasm pack publish test version-patch version-minor version-major

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

# Run tests against dist/
test:
	node tests/test.mjs

# Publish to npm (requires --otp if 2FA enabled: make publish OTP=123456)
publish:
	npm publish --access public $(if $(OTP),--otp $(OTP),)

# Version bumps — updates package.json and creates a git tag
version-patch:
	$(eval VERSION := $(shell jq -r '.version' package.json | awk -F. '{print $$1"."$$2"."$$3+1}'))
	jq '.version = "$(VERSION)"' package.json > package.json.tmp && mv package.json.tmp package.json
	git add package.json && git commit -m "chore: bump version to $(VERSION)"
	git tag v$(VERSION)
	git push
	git push --tags

version-minor:
	$(eval VERSION := $(shell jq -r '.version' package.json | awk -F. '{print $$1"."$$2+1".0"}'))
	jq '.version = "$(VERSION)"' package.json > package.json.tmp && mv package.json.tmp package.json
	git add package.json && git commit -m "chore: bump version to $(VERSION)"
	git tag v$(VERSION)
	git push
	git push --tags

version-major:
	$(eval VERSION := $(shell jq -r '.version' package.json | awk -F. '{print $$1+1".0.0"}'))
	jq '.version = "$(VERSION)"' package.json > package.json.tmp && mv package.json.tmp package.json
	git add package.json && git commit -m "chore: bump version to $(VERSION)"
	git tag v$(VERSION)
	git push
	git push --tags
