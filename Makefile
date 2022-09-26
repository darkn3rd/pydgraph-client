.PHONY: test build push clean

build:
	@docker build -t pydgraph-client:latest .

push:
	@docker tag pydgraph-client:latest $$DOCKER_REGISTRY/pydgraph-client:latest
	@docker push $$DOCKER_REGISTRY/pydgraph-client:latest

test: build
	@docker run --detach --name pydgraph_client pydgraph-client:latest

scan: build
	@docker scan pydgraph-client:latest

clean:
	@docker stop pydgraph_client && docker rm pydgraph_client
