FROM swift:6.1-jammy AS build
WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends libjemalloc-dev \
  && rm -rf /var/lib/apt/lists/*

COPY Package.* ./
RUN swift package resolve $([ -f ./Package.resolved ] && echo "--force-resolved-versions" || true)

COPY . .
RUN mkdir -p /staging

RUN set -eux; \
  swift build -c release -j 1 --product TuckServer -Xlinker -ljemalloc; \
  BIN="$(find /build/.build -type f -path '*/release/TuckServer' | head -n 1)"; \
  cp "$BIN" /staging/TuckServer; \
  find -L "$(dirname "$BIN")" -regex '.*\.resources$' -exec cp -Ra {} /staging \; || true; \
  mkdir -p /staging/swift-libs; \
  cp -a /usr/lib/swift/linux/*.so /staging/swift-libs/; \
  cp -a /usr/lib/swift/linux/*/*.so /staging/swift-libs/ 2>/dev/null || true

WORKDIR /staging
RUN cp "/usr/libexec/swift/linux/swift-backtrace-static" ./ || true
RUN if [ -d /build/Public ]; then mv /build/Public ./Public && chmod -R a-w ./Public; fi
RUN if [ -d /build/Resources ]; then mv /build/Resources ./Resources && chmod -R a-w ./Resources; fi

FROM ubuntu:jammy
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libjemalloc2 ca-certificates tzdata libssl3 libicu70 \
  && rm -rf /var/lib/apt/lists/*

# Swift runtime libs needed by the binary
COPY --from=build /staging/swift-libs /usr/lib/swift/linux
ENV LD_LIBRARY_PATH=/usr/lib/swift/linux

RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor
COPY --from=build --chown=vapor:vapor /staging /app

ENV SWIFT_BACKTRACE=enable=yes,sanitize=yes,threads=all,images=all,interactive=no,swift-backtrace=./swift-backtrace-static
USER vapor:vapor

EXPOSE 8080
CMD ["sh","-lc","./TuckServer serve --env production --hostname 0.0.0.0 --port ${PORT:-8080}"]
