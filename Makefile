# reusable-workflows Makefile

.DEFAULT_GOAL := help
.PHONY: help submodules sops-decrypt sops-encrypt lint lint-actions lint-md lint-yaml lint-gitleaks format format-check fix fix-md reuse-lint security ci

# Variables
# `format`/`format-check` default to markdown only. YAML is governed by
# yamllint; running prettier on workflow files may reflow them in
# unexpected ways. To opt in:
#   make format PRETTIER_GLOB='**/*.{md,yml,yaml,json}'
PRETTIER_GLOB ?= **/*.md
MARKDOWN_GLOB ?= **/*.md
# NOTE: `#` starts a comment in Makefiles even inside double quotes — use
# `\#` to embed it literally. These are markdownlint-cli2 exclusion globs
# (a `#` prefix tells it "exclude this path"). Mirror the CICD markdownlint
# job: skip CHANGELOG.md and the superpowers/ scratch plans.
MARKDOWNLINT_IGNORES := "\#.git" "\#.worktrees" "\#.remember" "\#.venv" "\#node_modules" "\#CHANGELOG.md" "\#**/superpowers/**" "\#secrets/*.sops.*"

## help: Show this help message
help:
	@echo "Make Commands"
	@echo ""
	@echo "Available targets:"
	@echo ""
	@awk '/^## [a-zA-Z0-9_-]+:/ { sub(/^## /, ""); split($$0, a, ": "); printf "  %-20s %s\n", a[1], a[2] }' $(MAKEFILE_LIST)
	@echo ""

## submodules: Initialize/reinitialize git submodules with force (sync URLs, recursive)
submodules:
	@if ! command -v git >/dev/null 2>&1; then \
		echo "Error: git is not installed or not in PATH"; \
		exit 1; \
	fi
	@if [ ! -f .gitmodules ]; then \
		echo "No .gitmodules found — nothing to initialize."; \
		exit 0; \
	fi
	@echo "Syncing submodule URLs from .gitmodules..."
	@git submodule sync --recursive
	@echo "Force-initializing submodules (recursive)..."
	@git submodule update --init --recursive --force
	@echo "Submodules initialized."

## sops-decrypt: Decrypt all SOPS-encrypted files (*.sops.enc.{yaml,yml,json} -> *.sops.dec.{yaml,yml,json})
sops-decrypt:
	@if ! command -v sops >/dev/null 2>&1; then \
		echo "Error: sops is not installed or not in PATH"; \
		exit 1; \
	fi; \
	SOPS_FILES=$$(find . -type f \( -name '*.sops.enc.yaml' -o -name '*.sops.enc.yml' -o -name '*.sops.enc.json' \) | sort -u); \
	if [ -z "$$SOPS_FILES" ]; then \
		echo "No *.sops.enc.{yaml,yml,json} files found for decryption."; \
		exit 0; \
	fi; \
	echo ""; \
	for work_file in $$SOPS_FILES; do \
		( \
			current_filename=$$(basename "$$work_file"); \
			secret_dir=$$(dirname "$$work_file"); \
			decrypted_filename=$${current_filename/.sops.enc./.sops.dec.}; \
			decrypted_file="$${secret_dir}/$${decrypted_filename}"; \
			case "$${current_filename##*.}" in \
				yaml|yml) sops_type=yaml ;; \
				json)     sops_type=json ;; \
				*)        echo "Error: unsupported extension on $$work_file" >&2; exit 1 ;; \
			esac; \
			echo "Decrypting: $$work_file -> $$decrypted_file"; \
			if ! sops --input-type $$sops_type --output-type $$sops_type -d "$$work_file" > "$$decrypted_file"; then \
				echo "Error: Failed to decrypt $$work_file" >&2; \
				exit 1; \
			fi; \
		) & \
		if [ $$(jobs -r -p | wc -l) -ge 4 ]; then wait -n; fi; \
	done; \
	wait; \
	echo "All decryption jobs completed."

## sops-encrypt: Encrypt all SOPS-decrypted files (*.sops.dec.{yaml,yml,json} -> *.sops.enc.{yaml,yml,json})
sops-encrypt:
	@if ! command -v sops >/dev/null 2>&1; then \
		echo "Error: sops is not installed or not in PATH"; \
		exit 1; \
	fi; \
	SOPS_FILES=$$(find . -type f \( -name '*.dec.yaml' -o -name '*.sops.dec.yml' -o -name '*.sops.dec.json' \) | sort -u); \
	if [ -z "$$SOPS_FILES" ]; then \
		echo "No *.sops.dec.{yaml,yml,json} files found for encryption."; \
		exit 0; \
	fi; \
	echo ""; \
	for work_file in $$SOPS_FILES; do \
		( \
			current_filename=$$(basename "$$work_file"); \
			secret_dir=$$(dirname "$$work_file"); \
			encrypted_filename=$${current_filename/.sops.dec./.sops.enc.}; \
			encrypted_file="$${secret_dir}/$${encrypted_filename}"; \
			case "$${current_filename##*.}" in \
				yaml|yml) sops_type=yaml ;; \
				json)     sops_type=json ;; \
				*)        echo "Error: unsupported extension on $$work_file" >&2; exit 1 ;; \
			esac; \
			if [ ! -f "$$encrypted_file" ] || [ "$$work_file" -nt "$$encrypted_file" ]; then \
				echo "Encrypting: $$work_file -> $$encrypted_file"; \
				if ! sops --input-type $$sops_type --output-type $$sops_type -e "$$work_file" > "$$encrypted_file"; then \
					echo "Error: Failed to encrypt $$work_file" >&2; \
					exit 1; \
				fi; \
			else \
				echo "Skipping: $$work_file (no changes detected)"; \
			fi; \
		) & \
		if [ $$(jobs -r -p | wc -l) -ge 4 ]; then wait -n; fi; \
	done; \
	wait; \
	echo "All encryption jobs completed."

## lint: Run all linters (GitHub Actions + markdown + YAML + secrets)
lint: lint-actions lint-yaml lint-md lint-gitleaks

## lint-actions: Lint workflows/actions with actionlint (uses .github/actionlint.yaml)
lint-actions:
	@if ! command -v actionlint >/dev/null 2>&1; then \
		echo "Error: actionlint is not installed (try: brew install actionlint)"; \
		exit 1; \
	fi
	@actionlint -shellcheck=shellcheck

## lint-md: Lint markdown files with markdownlint-cli2 (uses .markdownlint.yaml)
lint-md:
	@if ! command -v npx >/dev/null 2>&1; then \
		echo "Error: npx (Node.js) is not installed or not in PATH"; \
		exit 1; \
	fi
	@npx --yes markdownlint-cli2 "$(MARKDOWN_GLOB)" $(MARKDOWNLINT_IGNORES)

## lint-yaml: Lint YAML files with yamllint (uses .yamllint.yml)
lint-yaml:
	@if ! command -v yamllint >/dev/null 2>&1; then \
		echo "Error: yamllint is not installed (try: pip install yamllint or brew install yamllint)"; \
		exit 1; \
	fi
	@yamllint .

## format: Auto-format markdown/YAML/JSON with prettier (writes in place)
format:
	@if ! command -v prettier >/dev/null 2>&1; then \
		echo "Error: prettier is not installed (try: npm i -g prettier or brew install prettier)"; \
		exit 1; \
	fi
	@prettier --write "$(PRETTIER_GLOB)"

## format-check: Verify formatting without writing (CI-friendly)
format-check:
	@if ! command -v prettier >/dev/null 2>&1; then \
		echo "Error: prettier is not installed"; \
		exit 1; \
	fi
	@prettier --check "$(PRETTIER_GLOB)"

## fix-md: Auto-fix markdown (markdownlint --fix first, then prettier so the
##         final state is prettier-clean even if markdownlint rewrote any
##         lines that prettier would re-wrap).
fix-md:
	@if ! command -v prettier >/dev/null 2>&1 || ! command -v npx >/dev/null 2>&1; then \
		echo "Error: prettier and npx must be on PATH"; \
		exit 1; \
	fi
	@npx --yes markdownlint-cli2 --fix "$(MARKDOWN_GLOB)" $(MARKDOWNLINT_IGNORES) || true
	@prettier --write "$(MARKDOWN_GLOB)"

## fix: Run every auto-fixer (currently fix-md + format)
fix: fix-md format

## lint-gitleaks: Scan for committed secrets with gitleaks (uses .gitleaks.toml)
lint-gitleaks:
	@if ! command -v gitleaks >/dev/null 2>&1; then \
		echo "Error: gitleaks is not installed (try: brew install gitleaks)"; \
		exit 1; \
	fi
	@gitleaks detect --source . --config .gitleaks.toml --redact

## security: Alias for the secret-scanning lint
security: lint-gitleaks

## reuse-lint: Check REUSE compliance (SPDX licensing, uses REUSE.toml)
reuse-lint:
	@uvx reuse lint

## ci: Mirror the CICD workflow lint jobs locally
ci: lint reuse-lint
