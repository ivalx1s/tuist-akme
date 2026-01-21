#MARK: - Configuration
.PHONY: bootstrap ensure-env generate clean sync-modules sync-portal-capabilities module tuist-generate check-docs check-graph

# Default action when typing just 'make'
.DEFAULT_GOAL := generate

# Detect CI environments (common flags).
ifneq ($(CI)$(GITLAB_CI)$(GITHUB_ACTIONS),)
	IS_CI := true
	tuist_generate_args ?= --no-open
else
	IS_CI := false
endif

# Load repo-tracked and local environment variables (if present) and export them to child processes (Tuist).
-include .env.shared
-include .env
export

# Tuist manifests can only read `TUIST_*` variables when sandboxing is enabled.
# We keep the user-facing variable `DEVELOPMENT_TEAM_ID` and map it to `TUIST_DEVELOPMENT_TEAM_ID`.
ifndef TUIST_DEVELOPMENT_TEAM_ID
TUIST_DEVELOPMENT_TEAM_ID := $(DEVELOPMENT_TEAM_ID)
endif
export TUIST_DEVELOPMENT_TEAM_ID

# Bundle ID suffix is used to avoid local signing conflicts (for example `.ivan`).
# It gets inserted after the first two bundle ID components (e.g. `com.acme`) so wildcard App IDs
# like `com.acme.*` still match.
# We keep the user-facing variable `BUNDLE_ID_SUFFIX` and map it to `TUIST_BUNDLE_ID_SUFFIX`.
ifndef TUIST_BUNDLE_ID_SUFFIX
TUIST_BUNDLE_ID_SUFFIX := $(BUNDLE_ID_SUFFIX)
endif
export TUIST_BUNDLE_ID_SUFFIX

# Repo-tracked configuration is defined in `.env.shared` and mapped into `TUIST_*` so Tuist
# manifests can read it when sandboxing is enabled.
ifneq ($(strip $(WORKSPACE_NAME)),)
ifndef TUIST_WORKSPACE_NAME
TUIST_WORKSPACE_NAME := $(WORKSPACE_NAME)
endif
export TUIST_WORKSPACE_NAME
endif

ifneq ($(strip $(IOS_APP_PROJECT_NAME)),)
ifndef TUIST_IOS_APP_PROJECT_NAME
TUIST_IOS_APP_PROJECT_NAME := $(IOS_APP_PROJECT_NAME)
endif
export TUIST_IOS_APP_PROJECT_NAME
endif

ifneq ($(strip $(IOS_APP_NAME)),)
ifndef TUIST_IOS_APP_NAME
TUIST_IOS_APP_NAME := $(IOS_APP_NAME)
endif
export TUIST_IOS_APP_NAME
endif

ifneq ($(strip $(IOS_MIN_VERSION)),)
ifndef TUIST_IOS_MIN_VERSION
TUIST_IOS_MIN_VERSION := $(IOS_MIN_VERSION)
endif
export TUIST_IOS_MIN_VERSION
endif

ifneq ($(strip $(IOS_BASE_BUNDLE_ID)),)
ifndef TUIST_IOS_BASE_BUNDLE_ID
TUIST_IOS_BASE_BUNDLE_ID := $(IOS_BASE_BUNDLE_ID)
endif
export TUIST_IOS_BASE_BUNDLE_ID
endif

ifneq ($(strip $(MACOS_APP_PROJECT_NAME)),)
ifndef TUIST_MACOS_APP_PROJECT_NAME
TUIST_MACOS_APP_PROJECT_NAME := $(MACOS_APP_PROJECT_NAME)
endif
export TUIST_MACOS_APP_PROJECT_NAME
endif

ifneq ($(strip $(MACOS_APP_NAME)),)
ifndef TUIST_MACOS_APP_NAME
TUIST_MACOS_APP_NAME := $(MACOS_APP_NAME)
endif
export TUIST_MACOS_APP_NAME
endif

ifneq ($(strip $(MACOS_MIN_VERSION)),)
ifndef TUIST_MACOS_MIN_VERSION
TUIST_MACOS_MIN_VERSION := $(MACOS_MIN_VERSION)
endif
export TUIST_MACOS_MIN_VERSION
endif

ifneq ($(strip $(MACOS_BASE_BUNDLE_ID)),)
ifndef TUIST_MACOS_BASE_BUNDLE_ID
TUIST_MACOS_BASE_BUNDLE_ID := $(MACOS_BASE_BUNDLE_ID)
endif
export TUIST_MACOS_BASE_BUNDLE_ID
endif

#MARK: - Bootstrap (Setup Environment)
# 1. Checks/Installs Homebrew
# 2. Checks/Installs Tuist
# 3. Prompts for local environment (.env)
# 4. Fetches Dependencies
# 5. Creates a .bootstrapped marker file
bootstrap:
	@echo "🚀 Bootstrapping environment..."
	@# 1. Check Homebrew
	@if ! which brew > /dev/null; then \
		echo "🍺 Installing Homebrew..."; \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
		eval "$$(/opt/homebrew/bin/brew shellenv)"; \
	fi
	@# 2. Check Tuist
	@if ! which tuist > /dev/null; then \
		echo "🛠 Installing Tuist..."; \
		curl -Ls https://install.tuist.io | bash; \
	fi
	@# 3. Setup Local Environment (.env)
	@$(MAKE) ensure-env
	@# 4. Install Dependencies
	@echo "⬇️ Fetching dependencies..."
	@tuist install
	@# 5. Create marker file
	@touch .bootstrapped

#MARK: - Generate Project
# Checks for .bootstrapped marker. If missing, runs bootstrap first.
generate:
	@if [ ! -f .bootstrapped ]; then \
		echo "🆕 First time run detected. Initializing..."; \
		$(MAKE) bootstrap; \
	fi
	@$(MAKE) ensure-env
	@$(MAKE) sync-modules
	@$(MAKE) tuist-generate

#MARK: - Local Environment
ensure-env:
	@if [ "$(IS_CI)" = "true" ]; then \
		exit 0; \
	fi; \
	touch .env; \
	append_env() { \
		key="$$1"; value="$$2"; \
		if [ -s .env ]; then \
			printf "\n%s=%s\n" "$$key" "$$value" >> .env; \
		else \
			printf "%s=%s\n" "$$key" "$$value" > .env; \
		fi; \
	}; \
	has_key() { grep -q "^$$1=" .env; }; \
	if has_key DEVELOPMENT_TEAM_ID && has_key BUNDLE_ID_SUFFIX; then \
		exit 0; \
	fi; \
	echo "⚙️  Configuring local environment..."; \
	if ! has_key DEVELOPMENT_TEAM_ID; then \
		if [ -n "$(DEVELOPMENT_TEAM_ID)" ]; then \
			append_env DEVELOPMENT_TEAM_ID "$(DEVELOPMENT_TEAM_ID)"; \
			echo "✅ Saved Team ID to .env"; \
		else \
			printf "🔐 Enter your Apple Development Team ID (Press Enter to skip): "; \
			read team_id; \
			append_env DEVELOPMENT_TEAM_ID "$$team_id"; \
			if [ -n "$$team_id" ]; then \
				echo "✅ Saved Team ID to .env"; \
			else \
				echo "⚠️  Skipping Team ID. You may have signing issues on device."; \
			fi; \
		fi; \
	fi; \
	if ! has_key BUNDLE_ID_SUFFIX; then \
		if [ -n "$(BUNDLE_ID_SUFFIX)" ]; then \
			append_env BUNDLE_ID_SUFFIX "$(BUNDLE_ID_SUFFIX)"; \
			echo "✅ Saved bundle ID suffix to .env"; \
		else \
			printf "🪪 Enter a bundle ID suffix (e.g. .ivan) (Press Enter to skip): "; \
			read bundle_suffix; \
			append_env BUNDLE_ID_SUFFIX "$$bundle_suffix"; \
			if [ -n "$$bundle_suffix" ]; then \
				echo "✅ Saved bundle ID suffix to .env"; \
			fi; \
		fi; \
	fi

#MARK: - Modules
sync-modules:
	@python3 Scripts/sync_modules.py

sync-portal-capabilities:
	@# Intended for Tuist manifests/plugins helpers (not app source code).
	@python3 Scripts/sync_portal_capabilities.py

check-docs:
	@# Intended for Tuist manifests/plugins helpers (not app source code).
	@python3 Scripts/check_swift_docs.py

check-graph:
	@python3 Scripts/check_tuist_graph_architecture.py

module:
	@if [ -z "$(layer)" ] || [ -z "$(name)" ]; then \
		echo "Usage: make module layer=<feature|core|shared|utility> name=<ModuleName>"; \
		exit 1; \
	fi
	@python3 Scripts/create_module.py --layer $(layer) --name $(name)
	@$(MAKE) sync-modules

tuist-generate:
	@if [ -n "$(verbose)" ] || [ -n "$(VERBOSE)" ] || [ -n "$(V)" ] || [ -n "$(v)" ]; then \
		python3 Scripts/tuist_generate.py --verbose $(tuist_generate_args); \
	else \
		python3 Scripts/tuist_generate.py $(tuist_generate_args); \
	fi

#MARK: - Clean Project
# Removes artifacts AND the .bootstrapped marker
clean:
	@echo "🧹 Cleaning up..."
	@killall Xcode > /dev/null 2> /dev/null || :
	@rm -f .bootstrapped
	@rm -rf ~/Library/Caches/org.swift.swiftpm
	@rm -rf ~/.swiftpm/cache/
	@tuist clean
