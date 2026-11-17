# AGENTS.md

This repository packages web Tinker as a container image. It holds no Tinker code:
`upstream/` is a git submodule pinned at one commit of
<https://github.com/tinker-click/tinker-click>, built unmodified.

## Layout

- `docker/`: the Dockerfile (two stages) and the entrypoint's start check.
- `upstream/`: the pinned upstream commit. Never edit files in it; a change upstream
  goes to upstream as a pull request.
- `docs/`: how the image runs, how the pin moves, and the licence note.
- `Makefile`: `make help` lists the targets.

## Gates (run before committing)

- `make verify`: the variables, the targets, and `upstream/` at the pinned commit,
  unmodified, named by the newest row of `docs/pin.md`.
- `make it_build`: the image builds and its labels name the upstream commit and
  `AGPL-3.0-only`.
- `make it_run it_check` then `make invite >/dev/null`: the sign-in page answers, and
  the codes land in a file in the volume, never in a transcript. Then `make it_stop`.
  When a `tinker-web` container already runs on the machine (another session's), add
  `CONTAINER=tinker-web-test PORT=8798 VOLUME=tinker-web-test-data` to every target,
  so `it_stop` never stops it, and remove that volume afterwards.

## Rules for this repo

- **Nothing Sage-only in the image.** Every upstream variable passes through unchanged,
  and the node default stays upstream's. Extras for one deployment live in its own
  command or config, never here.
- **Upstream's warnings stay the defaults.** Port published on `127.0.0.1` only,
  `TENKTS_SERVER_ALLOW=@invalid` (invite codes only).
- **The pin moves in one commit** with the matching line in `docs/pin.md`;
  `make upstream_update` stages both.
- **Publishing** is `make it_build_multi_arch_push_GHCR` on the build VM
  (`DOCKER_CONTEXT=colima-build`), from a clean `vX.Y.Z` tag only. It pushes the version
  and `:latest` together and checks both carry amd64 and arm64.
- **Branches.** git-flow-next with the committed `.gitflow`: `develop` for work, `master`
  for releases, tags `vX.Y.Z`. Upstream's branch is whatever `.gitmodules` names; never
  hard-code it elsewhere.

## Shared rules

The same block sits in every Sage.is and Startr repo's AGENTS.md; change it everywhere or nowhere.

- **Git.** Agents commit and push only when the person they work for says so in that session. Commits are authored as that person and carry an AI co-author trailer. Subjects read `type(scope): subject` (`feat`, `fix`, `docs`, `refactor`, `test`, `chore`).
- **Design.** startr.style inline props in `style` attributes, never classes. Write the base (phone) value first; add an `-sm`/`-md`/`-lg`/`-xl` tier only where the layout changes, and never repeat the base value in a tier. New pages ship plain HTML first; never a third visual language. The kit's manual is [design-ingest.md](https://github.com/Startr/WEB-startr.style.core/blob/master/docs/design-ingest.md).
- **Browser checks are scripts.** `bun run probe:hover`, `probe:tap` and `probe:diff` run from a WEB-startr.style.core checkout and take seconds; they replace long agent sessions clicking through pages.
- **Steps.** A step in a runbook, run sheet or checklist is one command: `cd` to an absolute path, then commands joined with `&&` and broken with `\`, so it stops at its first failure and can later run unchanged as a Dockerfile `RUN` or a CI step. A step calls a make target, not inline logic. No inline `#` comments (interactive zsh runs them as commands), no pasted `set -e`, no heredocs; a step that needs a key touch, a password or `git add -p` stays its own [MANUALLY] step.
- **Board.** `TODO.md` sections are the kanban columns. Each card is one short claim line (under about 350 characters) with a sub-checklist; narration goes to `board-dossiers.md` in the docs folder. `KANBAN.canvas` is generated from `TODO.md`; never hand-edit it.
- **Names.** Tracked files name work paths, not people; only Alexander is named. Clients go by codename.
- **Secrets.** In the environment or the team vault; never in chat, a command line or a tracked file.
