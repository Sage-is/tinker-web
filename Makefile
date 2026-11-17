# 1. help (default target — must come first)
help:
	@echo "================================================"
	@echo "       $(OWNER)/$(PROJECT_NAME) by Startr.Cloud"
	@echo "================================================"
	@echo "This is the default make command."
	@echo "This command lists available make commands."
	@echo ""
	@echo "Usage example:"
	@echo "    make it_build it_run invite"
	@echo ""
	@echo "Available make commands:"
	@echo ""
	@LC_ALL=C $(MAKE) -pRrq -f $(firstword $(MAKEFILE_LIST)) : 2>/dev/null | \
		awk -v RS= -F: '/(^|\n)# Files(\n|$$)/,/(^|\n)# Finished Make data base/ { \
		if ($$1 !~ "^[#.]") {print $$1}}' | \
		sort | \
		grep -E -v -e '^[^[:alnum:]]' -e '^$@$$'
	@echo ""

# 2. Dynamic variables (git-derived)
PROJECTPATH := $(shell git rev-parse --show-toplevel)
PROJECT     := $(shell echo $$(basename $(PROJECTPATH)) | tr '[:upper:]' '[:lower:]')
# Use symbolic-ref (clean failure on empty repos) → short SHA (detached HEAD) → develop fallback.
FULL_BRANCH := $(shell git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "develop")
BRANCH      := $(shell echo $(FULL_BRANCH) | sed 's/.*\///' | tr '[:upper:]' '[:lower:]')
TAG         := $(shell git describe --always --tag 2>/dev/null || echo "v0.0.0")

# Owner and project name extracted from git remote URL
REMOTE_URL   := $(shell git config --get remote.origin.url 2>/dev/null || echo "unknown/unknown")
OWNER        := $(shell echo $(REMOTE_URL) | sed -E 's|.*[:/]([^/]+)/[^/]+(.git)?$$|\1|')
PROJECT_NAME := $(shell echo $(REMOTE_URL) | sed -E 's|.*[:/][^/]+/([^/]+)(.git)?$$|\1|' | sed 's/\.git$$//')

# One container per machine, named like the `tinker-web` command, so
# `docker exec tinker-web tinker-cli …` reads the same everywhere.
CONTAINER ?= $(PROJECT)

# 3. Load environment overrides from .env if present
-include .env

# 4. Project-specific custom targets
# docker uses its current context, or the DOCKER_CONTEXT environment variable.
# On the Studio, `colima` (the default profile: arm64, krunkit) builds and runs;
# `colima-build` (vz with Rosetta) makes the multi-arch push.
IMAGE        ?= ghcr.io/sage-is/tinker-web
PORT         ?= 8799
VOLUME       ?= tinker-web-data
INVITE_NAME  ?= demo
INVITE_COUNT ?= 3

# The image's tag: the git tag without its v (0.1.0, as the formula names it),
# else the short commit. -dirty when tracked files changed since that commit,
# so a label never names source the image was not built from.
DIRTY             := $(if $(shell git status --porcelain --untracked-files=no 2>/dev/null),-dirty)
VERSION           := $(patsubst v%,%,$(TAG))$(DIRTY)
REVISION          := $(shell git rev-parse --verify -q HEAD || echo unknown)$(DIRTY)
UPSTREAM_REVISION := $(shell git -C upstream rev-parse --verify -q HEAD || echo unknown)
# Upstream's branch, named once in .gitmodules (main today; master once Tinker
# moves to git-flow). This repo's own branches are develop and master either way.
UPSTREAM_BRANCH   := $(shell git config -f .gitmodules --get submodule.upstream.branch || echo main)
# The newest row of the table in docs/pin.md.
PIN_ROW = grep -m1 -E '^\| [0-9]{4}-[0-9]{2}-[0-9]{2} \|' docs/pin.md

# The image's labels name upstream's commit as the corresponding source, so the
# build stops unless upstream/ is exactly that commit, unmodified, and the newest
# row of docs/pin.md names it.
require_upstream:
	@if [ ! -f upstream/Cargo.toml ]; then \
		echo "Error: upstream/ is empty. Run: git submodule update --init upstream"; exit 1; \
	fi
	@if git submodule status upstream | grep -q '^[-+U]'; then \
		echo "Error: upstream/ is not at the pinned commit. Run: git submodule update upstream"; exit 1; \
	fi
	@if [ -n "$$(git -C upstream status --porcelain)" ]; then \
		echo "Error: upstream/ has local changes; the image ships upstream unmodified. See: git -C upstream status"; exit 1; \
	fi
	@pin=$$(git ls-files -s upstream | cut -d' ' -f2); \
	case "$$($(PIN_ROW))" in *"$$pin"*) ;; \
	*) echo "Error: the newest row of docs/pin.md does not name the staged pin $$pin"; exit 1;; esac

# Moves the pin to the tip of upstream's branch, or to REF=<commit>, stages it and
# adds the row to docs/pin.md. Then: make it_build, the gates in AGENTS.md, and one
# commit holding upstream and docs/pin.md.
upstream_update:
	git -C upstream fetch -q origin
	@old=$$(git -C upstream rev-parse HEAD); \
	git -C upstream checkout -q $(or $(REF),origin/$(UPSTREAM_BRANCH)) && \
	new=$$(git -C upstream rev-parse HEAD) && \
	git add upstream && \
	case "$$($(PIN_ROW))" in *"$$new"*) echo "upstream already pinned at $$new"; exit 0;; esac; \
	echo "upstream: $$(git -C upstream rev-list --count $$old..$$new) commits, $$old -> $$new"; \
	row="| $$(date +%F) | \`$$new\` | $$(git -C upstream log -1 --format=%s | tr '|' '/') |"; \
	awk -v row="$$row" '{ print } /^\| --- \| --- \| --- \|$$/ && !done { print row; done = 1 }' \
		docs/pin.md > docs/pin.md.tmp && mv docs/pin.md.tmp docs/pin.md
	@$(MAKE) --no-print-directory require_upstream && echo "upstream/ and docs/pin.md agree; next: make it_build"

it_build: require_upstream
	docker build -f docker/Dockerfile \
		--build-arg VERSION=$(VERSION) \
		--build-arg REVISION=$(REVISION) \
		--build-arg UPSTREAM_REVISION=$(UPSTREAM_REVISION) \
		-t $(IMAGE):$(VERSION) -t $(IMAGE):$(BRANCH) .
	@docker image inspect $(IMAGE):$(VERSION) --format '{{ json .Config.Labels }}'

# The last build on this branch, published on loopback only, as upstream asks.
# The node and its token come from the caller's environment (e.g. under
# `sage-secret run`), never the command line. Returns once the page answers, so
# `make it_run invite` never races the database tinker-cli needs.
it_run:
	docker run -d --name $(CONTAINER) --restart unless-stopped \
		-p 127.0.0.1:$(PORT):8799 \
		-v $(VOLUME):/data \
		$(if $(wildcard .env),--env-file .env) \
		-e TENKTS_WEB_NODE -e TENKTS_WEB_NODE_TOKEN \
		$(IMAGE):$(BRANCH)
	@for i in $$(seq 30); do \
		curl -fsS -o /dev/null http://localhost:$(PORT)/ 2>/dev/null && exit 0; sleep 1; \
	done; \
	docker logs --tail 20 $(CONTAINER); \
	echo "Error: nothing answered on localhost:$(PORT) within 30 s"; exit 1

# The page, then the model. Upstream serves the page even when the node refused
# the token ("web demo: no model."), so a container given a token must show one.
it_check:
	curl -fsS http://localhost:$(PORT)/ | grep -io '<title>[^<]*</title>'
	@line=$$(docker logs $(CONTAINER) 2>&1 | grep 'web demo:' | tail -n 1); \
	echo "$${line:-no node token: the page serves, no app can be built}"; \
	if docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' $(CONTAINER) | grep -q '^TENKTS_WEB_NODE_TOKEN=.'; then \
		case "$$line" in *"the model comes from"*) ;; \
		*) echo "Error: the container has a node token but no model"; exit 1;; esac; \
	fi

# Codes print only this once. --to also keeps them in the volume, readable by the
# tinker user only, so `make invite >/dev/null` keeps them out of a transcript.
invite:
	@f=/data/invites-$(INVITE_NAME)-$$(date -u +%Y%m%dT%H%M%SZ).txt; \
	docker exec $(CONTAINER) tinker-cli invites new --name $(INVITE_NAME) --count $(INVITE_COUNT) --to $$f && \
	echo "The codes are also in $$f: docker exec $(CONTAINER) cat $$f" >&2

logs:
	docker logs -f --tail 100 $(CONTAINER)

# 6. Publishing: both architectures, from a clean release tag only
# A credsStore whose helper is gone (Docker Desktop's "desktop" outlives the
# app) fails the login with "error getting credentials".
ghcr_login:
	@store=$$(sed -n 's/.*"credsStore"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$${DOCKER_CONFIG:-$$HOME/.docker}/config.json" 2>/dev/null); \
	[ -z "$$store" ] || command -v "docker-credential-$$store" >/dev/null || { echo "credsStore \"$$store\" in docker's config.json has no docker-credential-$$store, so the login would fail. sage-runtime status names the fix."; exit 1; }
	@gh auth status >/dev/null 2>&1 || { echo "gh CLI is not authenticated: gh auth login"; exit 1; }
	@gh auth token | docker login ghcr.io -u $$(gh api user -q .login) --password-stdin
	@echo "If the push is denied: gh auth refresh -s write:packages"

# A buildx builder remembers the context it was made in. One name per context
# keeps Docker Desktop's builder off Colima and Colima's off Docker Desktop.
ensure_builder:
	@b=multi-arch-builder-$$(docker context show); \
	docker buildx inspect $$b >/dev/null 2>&1 || docker buildx create --name $$b; \
	docker buildx use $$b

# A krunkit VM has no Rosetta, so linux/amd64 stages run under QEMU, slowly and
# at risk of running out of memory. The build VM (vz with Rosetta) runs them.
# A Colima socket sits in its profile's folder, beside colima.yaml; the legacy
# ~/.colima/docker.sock serves the default profile, and /var/run/docker.sock
# often links to a VM's socket. The loop is bounded: older macOS has no
# readlink -f, and a cycle must not hang. docker reports DOCKER_HOST's socket
# when it is set, and DOCKER_HOST outranks DOCKER_CONTEXT, so the build VM is
# reached only once it is unset. (Copied from Sage-is/trellis.)
build_vm_check:
	@sock=$$(docker context inspect -f '{{.Endpoints.docker.Host}}' 2>/dev/null) || exit 0; \
	path=$${sock#unix://}; \
	for _ in 1 2 3 4 5 6 7 8; do \
	  [ -L "$$path" ] || break; \
	  link=$$(readlink "$$path"); \
	  case "$$link" in /*) path=$$link ;; *) path=$$(dirname "$$path")/$$link ;; esac; \
	done; \
	dir=$$(dirname "$$path"); [ -f "$$dir/colima.yaml" ] || dir=$$dir/default; \
	if grep -qs '^vmType: krunkit' "$$dir/colima.yaml"; then \
	  echo "$$sock is a krunkit VM; multi-arch builds go to the build VM. Run: $${DOCKER_HOST:+unset DOCKER_HOST; }sage-runtime build-vm, then DOCKER_CONTEXT=colima-build make $(MAKECMDGOALS)"; exit 1; \
	fi

# Every pushed image names committed source: only an exact, clean vX.Y.Z tag.
require_release_tag:
	@echo "$(TAG)$(DIRTY)" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$$' || { \
		echo "Error: this commit is $(TAG)$(DIRTY); push only from a clean vX.Y.Z tag (make minor_release, then make release_finish)"; exit 1; }

# One multi-arch build pushes :$(VERSION) and :latest (the README pulls :latest),
# then both manifests must carry linux/amd64 and linux/arm64.
it_build_multi_arch_push_GHCR: require_release_tag require_upstream build_vm_check ghcr_login ensure_builder
	docker buildx build --platform linux/amd64,linux/arm64 -f docker/Dockerfile \
		--build-arg VERSION=$(VERSION) \
		--build-arg REVISION=$(REVISION) \
		--build-arg UPSTREAM_REVISION=$(UPSTREAM_REVISION) \
		-t $(IMAGE):$(VERSION) -t $(IMAGE):latest --push .
	scripts/verify-image-manifest.sh $(IMAGE):$(VERSION) $(IMAGE):latest

verify_image:
	@scripts/verify-image-manifest.sh $(IMAGE):$(VERSION) $(IMAGE):latest

# 7. Docker lifecycle
it_stop:
	-docker stop $(CONTAINER)
	-docker rm $(CONTAINER)

it_clean:
	docker image prune -f
	docker builder prune -f

# Removes the container and the images; the data volume stays.
it_gone: it_stop
	-docker rmi $(IMAGE):$(VERSION) $(IMAGE):$(BRANCH)

# 8. show_vars + verify
show_vars:
	@echo "=== Dynamic Variables ==="
	@echo "PROJECTPATH=$(PROJECTPATH)"
	@echo "PROJECT=$(PROJECT)"
	@echo "OWNER=$(OWNER)"
	@echo "PROJECT_NAME=$(PROJECT_NAME)"
	@echo "FULL_BRANCH=$(FULL_BRANCH)"
	@echo "BRANCH=$(BRANCH)"
	@echo "TAG=$(TAG)"
	@echo "CONTAINER=$(CONTAINER)"
	@echo "REMOTE_URL=$(REMOTE_URL)"
	@echo "IMAGE=$(IMAGE)"
	@echo "VERSION=$(VERSION)"
	@echo "DOCKER_CONTEXT=$$(docker context show 2>/dev/null)"
	@echo "REVISION=$(REVISION)"
	@echo "UPSTREAM_REVISION=$(UPSTREAM_REVISION)"
	@echo "UPSTREAM_BRANCH=$(UPSTREAM_BRANCH)"
	@echo ""

# One-shot scaffold self-check. Bundles every read-only verification into a
# single make invocation so post-scaffold testing isn't N separate processes.
verify: show_vars require_gitflow_next require_upstream
	@echo "=== Targets defined in this Makefile ==="
	@LC_ALL=C $(MAKE) -pRrq -f $(firstword $(MAKEFILE_LIST)) : 2>/dev/null | \
		awk -v RS= -F: '/(^|\n)# Files(\n|$$)/,/(^|\n)# Finished Make data base/ { \
		if ($$1 !~ "^[#.]") {print "  " $$1}}' | \
		sort -u | \
		grep -E -v -e '^  [^[:alnum:]]'
	@echo ""
	@echo "OK: Makefile scaffold verified."

# 9. Git-flow-next release/hotfix flow
require_gitflow_next:
	@if ! git flow version 2>/dev/null | grep -q 'git-flow-next'; then \
		echo "Error: git-flow-next required (Go rewrite). Install: brew install git-flow-next"; \
		exit 1; \
	fi

# With no tag yet, the first release is 0.1.0.
minor_release: require_gitflow_next
	# Start a minor release with incremented minor version
	git flow release start $$(git tag --sort=-v:refname | sed 's/^v//' | head -n 1 | awk -F'.' '{print $$1"."$$2+1".0"}' | grep . || echo 0.1.0) && echo "or use 'make release_finish' to finish the release"

patch_release: require_gitflow_next
	# Start a patch release with incremented patch version
	git flow release start $$(git tag --sort=-v:refname | sed 's/^v//' | head -n 1 | awk -F'.' '{print $$1"."$$2"."$$3+1}' | grep . || echo 0.1.0) && echo "or use 'make release_finish' to finish the release"

major_release: require_gitflow_next
	# Start a major release with incremented major version
	git flow release start $$(git tag --sort=-v:refname | sed 's/^v//' | head -n 1 | awk -F'.' '{print $$1+1".0.0"}' | grep . || echo 0.1.0) && echo "or use 'make release_finish' to finish the release"

hotfix: require_gitflow_next
	# Start a hotfix with incremented n.n.n.n version (incrementing the fourth number)
	git flow hotfix start $$(git tag --sort=-v:refname | sed 's/^v//' | head -n 1 | awk -F'.' '{print $$1"."$$2"."$$3"."$$4+1}') && echo "or use 'make hotfix_finish' to finish the hotfix"

release_finish: require_gitflow_next
	git flow release finish && git push origin develop && git push origin master && git push --tags && git checkout develop

hotfix_finish: require_gitflow_next
	git flow hotfix finish && git push origin develop && git push origin master && git push --tags && git checkout master

# 10. things_clean
things_clean:
	git clean --exclude='!.env*' -Xdf

# 11. .PHONY
.PHONY: help show_vars verify require_gitflow_next \
	minor_release patch_release major_release hotfix \
	release_finish hotfix_finish things_clean \
	it_stop it_clean it_gone \
	ghcr_login ensure_builder build_vm_check require_release_tag \
	it_build_multi_arch_push_GHCR verify_image \
	require_upstream upstream_update it_build it_run it_check invite logs
