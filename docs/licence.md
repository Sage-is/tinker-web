# Licence

Tinker is licensed under the GNU Affero General Public License, version 3 only
(`AGPL-3.0-only`). The licence text is `upstream/LICENSE`, and the image carries a
copy at `/usr/share/doc/tinker-web/LICENSE`.

This repository's own files (the Dockerfile, the entrypoint, the Makefile, the
scripts and these notes) are under the same licence: `LICENSE` at its root.

## What the image contains

- `tenkts-server` and `tinker-cli`, compiled from the upstream commit pinned in
  `upstream/` (see [pin.md](pin.md)), with no changes to upstream's code.
- Upstream's host page, `ui/`, copied as it is at that commit.
- Debian's `bookworm-slim` base and its `ca-certificates` package, under their own
  licences.

## Where the corresponding source is

Every image names its source in two labels:

- `tinker-web.upstream.source` and `tinker-web.upstream.revision`: the upstream
  repository and the exact commit compiled into the image.
- `org.opencontainers.image.source` and `org.opencontainers.image.revision`: this
  repository and the commit holding the Dockerfile that built it.

Both repositories are public, so the source for any published image can be fetched at
those two commits.

## If you change the code

The AGPL's section 13 applies to anyone who runs a modified version for users over a
network: those users must be offered the modified source. Build a changed image from a
public fork, and point `upstream/` at it, so the labels keep naming the source.
