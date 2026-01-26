# syntax=docker/dockerfile:1.6

FROM swift:6.1-noble AS build
WORKDIR /build

# 1) Resolve deps (cache SwiftPM downloads)
COPY Package.* ./
RUN --mount=type=cache,id=s/e4039a1b-0521-4364-86f8-8ce03cadc573-/root/.swiftpm,target=/root/.swiftpm \
    swift package resolve

# 2) Copy sources
COPY . .

# 3) Build (cache .build + SwiftPM). Use -j 2 to avoid timeouts; change to -j 1 if you hit OOM.
RUN --mount=type=cache,id=s/e4039a1b-0521-4364-86f8-8ce03cadc573-/build/.build,target=/build/.build \
    --mount=type=cache,id=s/e4039a1b-0521-4364-86f8-8ce03cadc573-/root/.swiftpm,target=/root/.swiftpm \
    set -eux; \
    mkdir -p /staging; \
    swift build -c release -j 2 --product TuckServer; \
    BIN_PATH="$(swift build -c release --show-bin-path)"; \
    cp "$BIN_PATH/TuckServer" /staging/; \
    find -L "$BIN_PATH" -regex '.*\.resources$' -exec cp -Ra {} /staging \;

# 4) Copy Public if present
RUN if [ -d /build/Public ]; then cp -R /build/Public /staging/Public; fi

# ---------- run image ----------
FROM swift:6.1-noble
WORKDIR /app

COPY --from=build /staging /app

EXPOSE 8080
CMD ["sh", "-lc", "./TuckServer serve --env production --hostname 0.0.0.0 --port ${PORT:-8080}"]
