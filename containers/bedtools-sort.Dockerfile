FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    bedtools \
    coreutils \
    procps \
    time \
    bash \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

CMD ["/bin/bash"]

