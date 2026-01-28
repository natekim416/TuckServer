FROM swift:6.1-jammy AS build
WORKDIR /build

# Combine apt operations and add build essentials
RUN apt-get update && apt-get install -y --no-install-recommends \
    libjemalloc-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy and resolve dependencies first (cached layer)
COPY Package.* ./
RUN --mount=type=cache,target=/root/.swiftpm \
    swift package resolve $([ -f ./Package.resolved ] && echo "--force-resolved-versions" || true)

# Copy source
COPY . .
RUN mkdir -p /staging

# Build with aggressive optimization settings for Railway
RUN --mount=type=cache,target=/build/.build \
    --mount=type=cache,target=/root/.swiftpm \
    set -eux; \
    swift build -c release \
        --product TuckServer \
        -Xswiftc -j1 \
        -Xswiftc -num-threads 1 \
        -Xswiftc -O \
        -Xlinker -ljemalloc; \
    BIN="$(find .build/release -type f -name 'TuckServer' | head -n 1)"; \
    cp "$BIN" /staging/TuckServer; \
    find -L ".build/release" -regex '.*\.resources$' -exec cp -Ra {} /staging \; || true; \
    mkdir -p /staging/swift-libs; \
    cp -a /usr/lib/swift/linux/*.so /staging/swift-libs/; \
    cp -a /usr/lib/swift/linux/*/*.so /staging/swift-libs/ 2>/dev/null || true

WORKDIR /staging
RUN cp "/usr/libexec/swift/linux/swift-backtrace-static" ./ || true
RUN [ -d /build/Public ] && mv /build/Public ./Public && chmod -R a-w ./Public || true
RUN [ -d /build/Resources ] && mv /build/Resources ./Resources && chmod -R a-w ./Resources || true

FROM ubuntu:jammy
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libjemalloc2 ca-certificates tzdata libssl3 libicu70 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /staging/swift-libs /usr/lib/swift/linux
ENV LD_LIBRARY_PATH=/usr/lib/swift/linux

RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor
COPY --from=build --chown=vapor:vapor /staging /app

ENV SWIFT_BACKTRACE=enable=yes,sanitize=yes,threads=all,images=all,interactive=no,swift-backtrace=./swift-backtrace-static
USER vapor:vapor

EXPOSE 8080
CMD ["sh","-c","./TuckServer serve --env production --hostname 0.0.0.0 --port ${PORT:-8080}"]
