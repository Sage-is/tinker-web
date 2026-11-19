# TODO

> **Convention** — Sections below map to kanban columns. Inline source-code
> tags use the same vocabulary so items stay cross-referenced between this
> file and the codebase. `KANBAN.canvas` auto-generates from this file and
> inline tags — do not hand-edit it.
>
> | Column      | Markdown section  | Inline tag  |
> |-------------|-------------------|-------------|
> | Backlog     | `## Backlog`      |             |
> | TODO        | `## TODO`         | `# TODO:`   |
> | In Progress | `## In Progress`  | `# FIXME:`  |
> | Bugs        | `## Bugs`         | `# BUG:`    |
> | Done        | `- [x]` items / `## Done` | —   |
>
> `# DEPRECATED:` tags should be tracked as TODO items for removal at the
> stated version.

Plan: `~/.claude/plans/precious-strolling-puzzle.md` (sessions S11 and S13).

## In Progress

- [x] **First release, v0.1.0, on GHCR (S13)**: both architectures, version tag and `:latest`, package public #release
  - [x] [WE] `make minor_release`, then `make release_finish` (2026-11-18: `v0.1.0` on `296eb2f`)
  - [x] [WE] `sage-runtime build-vm`, then the push: index `sha256:393c3761`, amd64 and arm64, on `0.1.0` and `:latest`
  - [x] [MANUALLY] Set the GHCR package `tinker-web` public (2026-11-19); [WE] `make verify_image` 6/6, and an anonymous pull by the tap's `tinker-web` 0.1.0
  - [x] [WE] The tap's `tinker-web` formula pins image `0.1.0` (tag `tinker-web-v0.1.0`; the Studio runs it from brew)

## Bugs

- [ ] **The release push builds amd64 under QEMU, and rustc dies there** (SIGSEGV, 2026-11-18) #release
  - [ ] [WE] `ensure_builder` makes a `docker-container` builder; its buildkit misses Rosetta and wraps amd64 steps in its own QEMU
  - [x] [WE] Workaround for v0.1.0: the same `buildx build` line with `--builder colima-build`, the engine's builder, which runs amd64 through Rosetta
  - [ ] [WE] Fix: on `colima-build`, use the engine's builder (containerd store); then tell Trellis and AI-UI, whose copies run amd64 under QEMU too
- [x] **`make verify_image` died with 127**: `scripts/lib/gate.sh` was never copied from AI-UI; now it is #release

## TODO

## Backlog

- [ ] **Make Sage-is/tinker-web public** (Alexander) #licence
  - [x] README, `docs/licence.md` and root `LICENSE` (AGPL-3.0-only) in place
  - [ ] [MANUALLY] Read the README and `docs/licence.md` as a newcomer
  - [x] [WE] `gh repo edit Sage-is/tinker-web --visibility public --accept-visibility-change-consequences` (2026-11-18, on Alexander's go, before his read)

- [ ] **Offer the Dockerfile upstream** after Tuesday, by pull request to tinker-click/tinker-click #upstream
  - [ ] [WE] Copy `docker/`, with the `upstream/` paths in its `COPY` lines turned into `.`
  - [ ] [WE] Draft the PR text from the README's run and settings sections
  - [ ] [MANUALLY] Open the PR; if the team takes it, this repo shrinks to the pin

- [ ] **Keep the pin current** with upstream: its `main` was 87 commits past `251183dc` on 2026-11-17 #upstream
  - [ ] [WE] Review upstream's new commits; then `make upstream_update`, `make it_build` and the gates in `AGENTS.md`
  - [ ] [WE] When Tinker moves to `master`: `git config -f .gitmodules submodule.upstream.branch master`, one commit

- [ ] **DRY/KISS pass** from the 2026-11-17 audit: one source per fact, fewer checks #housekeeping
  - [ ] [WE] Labels read both source URLs from git (`.gitmodules`, `remote.origin.url`); one `BUILD_ARGS` for both build targets
  - [ ] [WE] `require_upstream` fails when the README lacks a `"TENKTS_*"` name upstream reads; add `TENKTS_SERVER_SECRET_FILE`
  - [ ] [WE] Cut `docs/running.md`'s copies of the README's run line, localhost note, invite command and model section
  - [ ] [WE] One upstream check instead of two: `git submodule status` with `--init` in the hint
  - [ ] [WE] The push target calls `make verify_image` instead of repeating the manifest list

- [ ] **TodoScope alignment**: check the board against this file #housekeeping
  - [ ] [MANUALLY] Scan this repo in TodoScope; confirm the columns match
  - [ ] [WE] Review `.todoscope-exclude.csv` (excludes `upstream/`)

## Bugs

_No known bugs. Use `# BUG:` inline tags to flag defects in source._

## Done

- [x] **S11: the image from a pinned upstream commit** (2026-11-17)
  - [x] Repo by concept: `upstream/` at `251183dc`, `docker/`, `docs/`, Startr Makefile, `AGENTS.md`
  - [x] arm64 image builds on the Studio (171 MB); sign-in page on `localhost:8799`; invite codes
  - [x] git-flow `develop`/`master`; upstream's branch named once in `.gitmodules`
  - [x] Mistake-proofing: pin checks, `-dirty` labels, run wait, model check, invite file, release-only push
  - [x] Root `LICENSE`, AGPL-3.0-only
