FROM python:3.9.6-buster
RUN mkdir -p /usr/src/app/data
WORKDIR /usr/src/app

# application package manifest
COPY requirements.txt /usr/src/app/
RUN pip install -r requirements.txt
# application source code
COPY . /usr/src/app

# install packages: jq
RUN apt-get update && apt-get install -y --no-install-recommends jq vim \
  && rm -rf /var/lib/apt/lists/*

# grpcurl
ADD https://raw.githubusercontent.com/dgraph-io/pydgraph/master/pydgraph/proto/api.proto api.proto
ADD https://github.com/fullstorydev/grpcurl/releases/download/v1.8.7/grpcurl_1.8.7_linux_x86_64.tar.gz /tmp
RUN tar -xzf /tmp/grpcurl_1.8.7_linux_x86_64.tar.gz -C /tmp \
  && rm /tmp/grpcurl_1.8.7_linux_x86_64.tar.gz \
  && mv /tmp/grpcurl /usr/local/bin

# download dgraph linux binaries
ADD https://github.com/dgraph-io/dgraph/releases/download/v21.03.2/dgraph-linux-amd64.tar.gz /tmp
RUN tar -xzf /tmp/dgraph-linux-amd64.tar.gz -C /tmp \
  && rm /tmp/dgraph-linux-amd64.tar.gz \
  && mv /tmp/badger /tmp/dgraph /usr/local/bin

# datasets
ADD https://raw.githubusercontent.com/dgraph-io/benchmarks/master/data/1million.schema /usr/src/app/data/1million.schema
ADD https://github.com/dgraph-io/benchmarks/raw/master/data/1million.rdf.gz /usr/src/app/data/1million.rdf.gz
ADD https://raw.githubusercontent.com/dgraph-io/benchmarks/master/data/21million.schema /usr/src/app/data/21million.schema
ADD https://github.com/dgraph-io/benchmarks/raw/master/data/21million.rdf.gz /usr/src/app/data/21million.rdf.gz

CMD exec /bin/bash -c "trap : TERM INT; sleep infinity & wait"
