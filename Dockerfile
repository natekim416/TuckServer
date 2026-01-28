# syntax=docker/dockerfile:1.6

FROM swift:6.1-noble AS build
WORKDIR /build

# Cache SwiftPM deps
COPY Package.* ./
RUN --mount=type=cache,id=tuck-swiftpm,target=/root/.swiftpm \
    swift package resolve

# Copy sources
COPY . .

# Build once, then copy the binary without calling SwiftPM again
RUN --mount=type=cache,id=tuck-build,target=/build/.build \
    --mount=type=cache,id=tuck-swiftpm,target=/root/.swiftpm \
    set -eux; \
    mkdir -p /staging; \
    swift build -c release -j 2 --product TuckServer; \
    BIN="$(find /build/.build -type f -path '*/release/TuckServer' | head -n 1)"; \
    test -n "$BIN"; \
    cp "$BIN" /staging/; \
    strip /staging/TuckServer || true; \
    find /build/.build -regex '.*\.resources$' -exec cp -Ra {} /staging \;

# Copy Public if present
RUN if [ -d /build/Public ]; then cp -R /build/Public /staging/Public; fi


# ---------- runtime image (small) ----------
FROM ubuntu:noble
WORKDIR /app

# Install only what the built binary typically needs on Linux
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      tzdata \
      libssl3 \
      libicu74 \
    ; \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /staging /app

ENV PORT=8080
EXPOSE 8080

CMD ["sh", "-lc", "./TuckServer serve --env production --hostname 0.0.0.0 --port ${PORT}"]
