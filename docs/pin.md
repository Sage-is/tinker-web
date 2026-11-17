# The upstream pin

`upstream/` is a git submodule of <https://github.com/tinker-click/tinker-click>, pinned
at one commit. The image is built from that commit, unmodified, and its labels name it:

```sh
docker image inspect ghcr.io/sage-is/tinker-web:<version> \
  --format '{{ index .Config.Labels "tinker-web.upstream.revision" }}'
```

## Current pin

| Since | Upstream commit | Upstream subject |
| --- | --- | --- |
| 2026-11-17 | `251183dcacf9ce67622e68bba86d6c3507756407` | Design: shared page data on GUN, with a Tinker super node |

## Moving the pin

From the repository root:

```sh
make upstream_update && make it_build
```

`make upstream_update` fetches upstream, checks out the tip of upstream's branch (or
`REF=<commit>`), stages it, and adds its row to the table above. Then run the gates in
`AGENTS.md` and commit the submodule change and this file together. `make it_build`
refuses to build when `upstream/` is missing or sits at a commit other than the one
staged.

## Branches

This repository uses git-flow: work lands on `develop`, releases on `master`, tagged
`vX.Y.Z`. Upstream keeps its own branch names. `.gitmodules` names the one the pin
follows (`main` today), so `make upstream_update` and
`git submodule update --remote upstream` both read it. If upstream renames that branch
(say, to `master`), change one line and commit it:

```sh
git config -f .gitmodules submodule.upstream.branch master
```

## Before cloning

Clone with the submodule, or fetch it afterwards:

```sh
git clone --recurse-submodules https://github.com/Sage-is/tinker-web.git
git submodule update --init upstream
```
