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
# The image and where it runs. DOCKER_CONTEXT=colima is Colima's `default`
# profile (arm64); colima-build makes the amd64 half.
IMAGE          ?= ghcr.io/sage-is/tinker-web
DOCKER_CONTEXT ?= colima
DOCKER         := docker --context $(DOCKER_CONTEXT)
PORT           ?= 8799
VOLUME         ?= tinker-web-data
INVITE_NAME    ?= demo
INVITE_COUNT   ?= 3

REVISION          := $(shell git rev-parse --verify -q HEAD || echo unknown)
UPSTREAM_REVISION := $(shell git -C upstream rev-parse --verify -q HEAD || echo unknown)
# Upstream's branch, named once in .gitmodules (main today; master once Tinker
# moves to git-flow). This repo's own branches are develop and master either way.
UPSTREAM_BRANCH   := $(shell git config -f .gitmodules --get submodule.upstream.branch || echo main)

# upstream/ must sit exactly at the pinned commit: the image's labels name it as
# the corresponding source, so a moved or missing checkout stops the build.
require_upstream:
	@if [ ! -f upstream/Cargo.toml ]; then \
		echo "Error: upstream/ is empty. Run: git submodule update --init upstream"; exit 1; \
	fi
	@if git submodule status upstream | grep -q '^[-+U]'; then \
		echo "Error: upstream/ is not at the pinned commit. Run: git submodule update upstream"; exit 1; \
	fi

# Moves the pin to the tip of upstream's branch, or to REF=<commit>, stages it and
# adds the row to docs/pin.md. Then: make it_build, the gates in AGENTS.md, and one
# commit holding upstream and docs/pin.md.
upstream_update:
	git -C upstream fetch -q origin
	@old=$$(git -C upstream rev-parse HEAD); \
	git -C upstream checkout -q $(or $(REF),origin/$(UPSTREAM_BRANCH)) && \
	new=$$(git -C upstream rev-parse HEAD) && \
	git add upstream && \
	if grep -q "$$new" docs/pin.md; then echo "upstream already pinned at $$new"; exit 0; fi; \
	echo "upstream: $$(git -C upstream rev-list --count $$old..$$new) commits, $$old -> $$new"; \
	row="| $$(date +%F) | \`$$new\` | $$(git -C upstream log -1 --format=%s | tr '|' '/') |"; \
	awk -v row="$$row" '{ print } /^\| --- \| --- \| --- \|$$/ && !done { print row; done = 1 }' \
		docs/pin.md > docs/pin.md.tmp && mv docs/pin.md.tmp docs/pin.md && \
	echo "docs/pin.md has the new row; next: make it_build"

it_build: require_upstream
	$(DOCKER) build -f docker/Dockerfile \
		--build-arg VERSION=$(TAG) \
		--build-arg REVISION=$(REVISION) \
		--build-arg UPSTREAM_REVISION=$(UPSTREAM_REVISION) \
		-t $(IMAGE):$(TAG) -t $(IMAGE):$(BRANCH) .
	@$(DOCKER) image inspect $(IMAGE):$(TAG) --format '{{ json .Config.Labels }}'

# Loopback only, as upstream asks. The node and its token come from the
# caller's environment (e.g. under `sage-secret run`), never the command line.
it_run:
	$(DOCKER) run -d --name $(CONTAINER) --restart unless-stopped \
		-p 127.0.0.1:$(PORT):8799 \
		-v $(VOLUME):/data \
		$(if $(wildcard .env),--env-file .env) \
		-e TENKTS_WEB_NODE -e TENKTS_WEB_NODE_TOKEN \
		$(IMAGE):$(TAG)

it_check:
	curl -fsS http://localhost:$(PORT)/ | grep -io '<title>[^<]*</title>'

invite:
	$(DOCKER) exec $(CONTAINER) tinker-cli invites new --name $(INVITE_NAME) --count $(INVITE_COUNT)

logs:
	$(DOCKER) logs -f --tail 100 $(CONTAINER)

# 7. Docker lifecycle
it_stop:
	-$(DOCKER) stop $(CONTAINER)
	-$(DOCKER) rm $(CONTAINER)

it_clean:
	$(DOCKER) image prune -f
	$(DOCKER) builder prune -f

# Removes the container and the images; the data volume stays.
it_gone: it_stop
	-$(DOCKER) rmi $(IMAGE):$(TAG) $(IMAGE):$(BRANCH)

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
	@echo "DOCKER_CONTEXT=$(DOCKER_CONTEXT)"
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
	require_upstream upstream_update it_build it_run it_check invite logs
