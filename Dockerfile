# syntax=docker/dockerfile:1

FROM swift:6.1-noble AS build
WORKDIR /build

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
  && apt-get -q update \
  && apt-get -q dist-upgrade -y \
  && apt-get install -y libjemalloc-dev \
  && rm -rf /var/lib/apt/lists/*

COPY Package.* ./
RUN swift package resolve

COPY . .

RUN set -eux; \
    mkdir -p /staging; \
    swift build -c release -j 1 \
      --product TuckServer \
      -Xlinker -ljemalloc; \
    BIN_PATH="$(swift build -c release --show-bin-path)"; \
    cp "$BIN_PATH/TuckServer" /staging/; \
    find -L "$BIN_PATH" -regex '.*\.resources$' -exec cp -Ra {} /staging \;

# Optional: copy Public if you have it
RUN if [ -d /build/Public ]; then cp -R /build/Public /staging/Public; fi

FROM ubuntu:noble AS run
WORKDIR /app

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
  && apt-get -q update \
  && apt-get -q dist-upgrade -y \
  && apt-get -q install -y libjemalloc2 ca-certificates tzdata \
  && rm -rf /var/lib/apt/lists/*

COPY --from=build /staging /app

EXPOSE 8080
CMD ["sh", "-lc", "./TuckServer serve --env production --hostname 0.0.0.0 --port ${PORT:-8080}"]
