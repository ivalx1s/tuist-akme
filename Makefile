#MARK: - Configuration
.PHONY: bootstrap generate clean sync-modules module tuist-generate

# Default action when typing just 'make'
.DEFAULT_GOAL := generate

ifdef GITLAB_CI
	tuist_generate_args := --no-open
endif

#MARK: - Bootstrap (Setup Environment)
# 1. Checks/Installs Homebrew
# 2. Checks/Installs Tuist
# 3. Fetches Dependencies
# 4. Creates a .bootstrapped marker file
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
	@# 3. Install Dependencies
	@echo "⬇️ Fetching dependencies..."
	@tuist install
	@# 4. Create marker file
	@touch .bootstrapped

#MARK: - Generate Project
# Checks for .bootstrapped marker. If missing, runs bootstrap first.
generate:
	@if [ ! -f .bootstrapped ]; then \
		echo "🆕 First time run detected. Initializing..."; \
		$(MAKE) bootstrap; \
	fi
	@$(MAKE) sync-modules
	@$(MAKE) tuist-generate

#MARK: - Modules
sync-modules:
	@python3 Scripts/sync_modules.py

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
