.PHONY: test build push clean

BUILD_VERSION ?= $(shell git describe --always --tags)


build:
	@docker build -t pydgraph-client:$(BUILD_VERSION) .

push:
	@docker tag pydgraph-client:$(BUILD_VERSION) $$DOCKER_REGISTRY/pydgraph-client:$(BUILD_VERSION)
	@docker push $$DOCKER_REGISTRY/pydgraph-client:$(BUILD_VERSION)

latest: push
	@docker tag pydgraph-client:$(BUILD_VERSION) $$DOCKER_REGISTRY/pydgraph-client:latest
	@docker push $$DOCKER_REGISTRY/pydgraph-client:latest

test: build
	@docker run --detach --name pydgraph_client pydgraph-client:latest

scan: build
	@docker scan pydgraph-client:latest

clean:
	@docker stop pydgraph_client && docker rm pydgraph_client
