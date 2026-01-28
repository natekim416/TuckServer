# ================================
# Build image
# ================================
FROM swift:6.1-jammy AS build
WORKDIR /build

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q install -y --no-install-recommends libjemalloc-dev \
    && rm -rf /var/lib/apt/lists/*

COPY Package.* ./
RUN swift package resolve \
    $([ -f ./Package.resolved ] && echo "--force-resolved-versions" || true)

COPY . .
RUN mkdir -p /staging

RUN --mount=type=cache,id=s/e4039a1b-0521-4364-86f8-8ce03cadc573-/build/.build,target=/build/.build \
    --mount=type=cache,id=s/e4039a1b-0521-4364-86f8-8ce03cadc573-/root/.swiftpm,target=/root/.swiftpm \
    set -eux; \
    swift build -c release -j 1 --product TuckServer -Xlinker -ljemalloc: \
    BIN="$(find /build/.build -type f -path '*/release/TuckServer' | head -n 1)"; \
    test -n "$BIN"; \
    cp "$BIN" /staging/TuckServer; \
    find -L "$(dirname "$BIN")" -regex '.*\.resources$' -exec cp -Ra {} /staging \; || true


WORKDIR /staging
RUN cp "/usr/libexec/swift/linux/swift-backtrace-static" ./ || true
RUN if [ -d /build/Public ]; then mv /build/Public ./Public && chmod -R a-w ./Public; fi
RUN if [ -d /build/Resources ]; then mv /build/Resources ./Resources && chmod -R a-w ./Resources; fi

# ================================
# Run image
# ================================
FROM swift:6.1-jammy
WORKDIR /app

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q install -y --no-install-recommends \
      libjemalloc2 ca-certificates tzdata \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor
COPY --from=build --chown=vapor:vapor /staging /app

ENV SWIFT_BACKTRACE=enable=yes,sanitize=yes,threads=all,images=all,interactive=no,swift-backtrace=./swift-backtrace-static
USER vapor:vapor

EXPOSE 8080
CMD ["sh","-lc","./TuckServer serve --env production --hostname 0.0.0.0 --port ${PORT:-8080}"]
