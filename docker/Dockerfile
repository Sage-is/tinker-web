# syntax=docker/dockerfile:1
#
# Web Tinker: upstream's tenkts-server with TENKTS_WEB=1, serving the host page (ui/)
# on port 8799, plus tinker-cli for invite codes and accounts. Built unmodified from
# the upstream commit pinned in upstream/ (a git submodule). Build context: this
# repository's root (see `make it_build`).
#
# Never put it on a public address: upstream's web mode is for internal use, and the
# apps it builds share the server's origin. See docs/running.md.

ARG RUST_VERSION=1.89
ARG DEBIAN_RELEASE=bookworm

# --- Build: the two binaries of the tenkts-server package -----------------------------
FROM rust:${RUST_VERSION}-${DEBIAN_RELEASE} AS build
WORKDIR /src
# The whole workspace: cargo reads every member's manifest, and the server compiles in
# files from core/ and src-tauri/src/widget_*.
COPY upstream/ ./
RUN --mount=type=cache,target=/usr/local/cargo/registry,sharing=locked \
    --mount=type=cache,target=/usr/local/cargo/git,sharing=locked \
    --mount=type=cache,target=/src/target,sharing=locked \
    cargo build --locked --release -p tenkts-server --bins \
 && install -D -m 0755 -t /out target/release/tenkts-server target/release/tinker-cli

# --- Run: the binaries, the host page and a data volume ---------------------------------
FROM debian:${DEBIAN_RELEASE}-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --system --uid 10001 --user-group --home-dir /data --no-create-home tinker \
 && mkdir -p /data \
 && chown tinker:tinker /data

COPY --from=build /out/ /usr/local/bin/
COPY upstream/ui/ /srv/ui/
COPY upstream/LICENSE /usr/share/doc/tinker-web/LICENSE
COPY docker/entrypoint.sh /usr/local/bin/tinker-web-entrypoint

# Upstream's warnings as defaults: invite-only (no address signs up without a code), and
# the bind is 0.0.0.0 only inside the container. Publish it on 127.0.0.1.
ENV TENKTS_WEB=1 \
    TENKTS_SERVER_BIND=0.0.0.0:8799 \
    TENKTS_SERVER_DATA=/data \
    TENKTS_WEB_UI=/srv/ui \
    TENKTS_SERVER_ALLOW=@invalid

USER tinker
WORKDIR /data
EXPOSE 8799
VOLUME /data
ENTRYPOINT ["tinker-web-entrypoint"]
CMD ["tenkts-server"]

# Last, so a new version or commit reuses every layer above.
ARG VERSION=dev
ARG REVISION=unknown
ARG UPSTREAM_REVISION=unknown
LABEL org.opencontainers.image.title="tinker-web" \
      org.opencontainers.image.description="Web Tinker (tenkts-server with TENKTS_WEB=1) from a pinned upstream commit" \
      org.opencontainers.image.licenses="AGPL-3.0-only" \
      org.opencontainers.image.source="https://github.com/Sage-is/tinker-web" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${REVISION}" \
      tinker-web.upstream.source="https://github.com/tinker-click/tinker-click" \
      tinker-web.upstream.revision="${UPSTREAM_REVISION}"
