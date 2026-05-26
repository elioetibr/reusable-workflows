# Composite Actions Scaffolding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scaffold the structure, tooling, and contributor docs for the `elioetibr/composite-actions` monorepo. No concrete actions yet — only the bed they will live in.

**Architecture:** Monorepo layout (`actions/<name>/action.yml` pattern). Repo-wide single version managed by release-please, with a floating major tag (`v1`) for consumers. Four parallel lint jobs gate every PR via one aggregator check.

**Tech Stack:** GitHub Actions (composite + reusable), release-please, actionlint, yamllint, markdownlint-cli2, action-docs (npm).

**Working directory:** `/Volumes/Development/personal/elioetibr/github/composite-actions/`

**Spec:** `docs/superpowers/specs/2026-05-19-composite-actions-scaffolding-design.md`

**Conventions applied throughout:**

- All commits GPG-signed (`git commit -S`) per user's global rule.
- No `Co-Authored-By` trailer ever.
- Commit messages follow Conventional Commits (`chore:`, `feat:`, `docs:`, `ci:`).
- Loosest available tag for every `uses:` reference.

---

## Pre-flight

- [ ] **Verify working directory and clean state**

```bash
cd /Volumes/Development/personal/elioetibr/github/composite-actions
git status
git rev-parse --abbrev-ref HEAD
```

Expected: branch `main`, only `.gitignore`, `README.md`, `LICENSE`, `LICENSE-APACHE-2.0`, `LICENSE-MIT` tracked. No uncommitted changes other than what's listed.

- [ ] **Verify required tools are available locally**

```bash
command -v actionlint || brew install actionlint
command -v yamllint || pip3 install --user yamllint
command -v markdownlint-cli2 || npm install -g markdownlint-cli2
command -v node && node --version  # action-docs is run via npx, needs Node
```

Expected: all four commands present. If `actionlint` is missing on macOS without Homebrew, download from <https://github.com/rhysd/actionlint/releases> and place in `$PATH`.

---

## Task 1: Foundation files (.editorconfig, .gitignore, lint configs)

**Why first:** Subsequent tasks generate YAML and Markdown that must pass these linters. Defining the rules first keeps every commit green from the start.

**Files:**

- Create: `.editorconfig`
- Modify: `.gitignore` (currently empty)
- Create: `.markdownlint.yaml`
- Create: `.yamllint.yaml`

- [ ] **Step 1: Write `.editorconfig`**

Create `.editorconfig`:

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
indent_style = space
indent_size = 2
insert_final_newline = true
trim_trailing_whitespace = true

[Makefile]
indent_style = tab

[*.md]
trim_trailing_whitespace = false
```

- [ ] **Step 2: Replace `.gitignore`**

Overwrite `.gitignore`:

```gitignore
# IDE
.idea/
.vscode/

# OS
.DS_Store
Thumbs.db

# Node (action-docs runtime)
node_modules/

# Python (yamllint runtime, if installed locally)
.venv/
__pycache__/

# Logs
*.log

# Terraform (not used here, but matches user-wide preference)
.terraform/
```

- [ ] **Step 3: Write `.markdownlint.yaml`**

Create `.markdownlint.yaml`:

```yaml
default: true
MD013: false   # line length — too noisy on tables and URLs
MD022: true   # blanks around headings (explicit per user preference)
MD032: true   # blanks around lists (explicit per user preference)
MD033: false  # allow inline HTML (action-docs uses HTML comment markers, README badges may use <img>)
MD041: false  # first line need not be a top-level heading (action READMEs start with markers)
```

- [ ] **Step 4: Write `.yamllint.yaml`**

Create `.yamllint.yaml`:

```yaml
---
extends: default

rules:
  line-length:
    max: 200
    level: warning
  truthy:
    check-keys: false   # workflow `on:` keys are falsey-looking but valid
  comments-indentation: disable
  document-start: disable
  indentation:
    spaces: 2
    indent-sequences: true
    check-multi-line-strings: false
```

- [ ] **Step 5: Verify linters accept their own configs**

```bash
yamllint .yamllint.yaml
yamllint .
markdownlint-cli2 "**/*.md" "#node_modules" "#.venv"
```

Expected: `yamllint` exits 0 (no output). `markdownlint-cli2` exits 0 on currently-tracked `.md` files (the empty `README.md` may emit nothing).

- [ ] **Step 6: Commit**

```bash
git add .editorconfig .gitignore .markdownlint.yaml .yamllint.yaml
git commit -S -m "chore: add editor and lint configs (editorconfig, gitignore, markdownlint, yamllint)"
```

---

## Task 2: Root README and SECURITY.md

**Why now:** Provides the top-of-funnel documentation. Empty `README.md` currently fails the eye-test even though it lints fine.

**Files:**

- Modify: `README.md` (currently empty)
- Create: `SECURITY.md`

- [ ] **Step 1: Replace `README.md`**

Overwrite `README.md`:

```markdown
# composite-actions

Reusable GitHub composite actions, maintained as a monorepo.

## Available actions

<!-- actions-index:start -->

_No actions published yet._

<!-- actions-index:end -->

## Usage

Reference any action from a workflow like this:

```yaml
- uses: elioetibr/composite-actions/actions/<name>@v1
  with:
    # action-specific inputs
```

## Version pinning

| Pin style | Example | When to use |
| --- | --- | --- |
| Floating major (recommended) | `@v1` | You want patch + minor fixes automatically. Default for most consumers. |
| Exact semver | `@v1.2.3` | You need a frozen, reproducible reference. |
| Commit SHA | `@<40-char-sha>` | Only when no tag exists yet. Loosest published tag is always preferred over a SHA pin. |

## Contributing

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for the recipe to add a new action and the release flow.

## Security

See [SECURITY.md](SECURITY.md) to report a vulnerability.

## License

Dual-licensed under **Apache-2.0 OR MIT**, at your option. See [LICENSE](LICENSE),
[LICENSE-APACHE-2.0](LICENSE-APACHE-2.0), and [LICENSE-MIT](LICENSE-MIT).
```

- [ ] **Step 2: Write `SECURITY.md`**

Create `SECURITY.md`:

```markdown
# Security Policy

## Supported versions

| Version | Supported |
| --- | --- |
| `v1.x` (latest) | Yes |
| Older majors | No |

## Reporting a vulnerability

Please use [GitHub private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing/privately-reporting-a-security-vulnerability)
on this repository. If that channel is unavailable, email <elioseverojunior@gmail.com>
with the subject line `[security] composite-actions: <summary>`.

We aim to:

- Acknowledge reports within 5 business days.
- Provide an initial assessment within 10 business days.
- Disclose publicly within 90 days of acknowledgement (sooner if a fix ships).

Please do not file public issues for suspected vulnerabilities.
```

- [ ] **Step 3: Verify markdown lints**

```bash
markdownlint-cli2 "README.md" "SECURITY.md"
```

Expected: exit 0, no warnings.

- [ ] **Step 4: Commit**

```bash
git add README.md SECURITY.md
git commit -S -m "docs: add root README and SECURITY policy"
```

---

## Task 3: Contributor experience (CODEOWNERS, PR + issue templates, CONTRIBUTING.md)

**Files:**

- Create: `.github/CODEOWNERS`
- Create: `.github/PULL_REQUEST_TEMPLATE.md`
- Create: `.github/ISSUE_TEMPLATE/bug_report.md`
- Create: `.github/ISSUE_TEMPLATE/feature_request.md`
- Create: `.github/ISSUE_TEMPLATE/config.yml`
- Create: `docs/CONTRIBUTING.md`

- [ ] **Step 1: Create `.github/CODEOWNERS`**

```text
# Default owner for every path
* @elioetibr
```

- [ ] **Step 2: Create `.github/PULL_REQUEST_TEMPLATE.md`**

```markdown
## What

<!-- Short description of the change. -->

## Why

<!-- Motivation. Link an issue if one exists: closes #NNN -->

## Action(s) affected

<!-- e.g. actions/setup-tools, actions/docker-build. Use "n/a" for repo-wide changes. -->

## Testing

<!-- How was this validated? Local lint? `act` run? Real workflow trigger? -->

## Checklist

- [ ] Conventional Commits used in commit messages
- [ ] `npx action-docs --update-readme` run if any `action.yml` changed
- [ ] Root `README.md` actions index updated if a new action was added
- [ ] `SECURITY.md` reviewed if this changes the threat model
- [ ] Breaking change? If yes, describe migration below

### Breaking change notes

<!-- Leave empty if not applicable. -->
```

- [ ] **Step 3: Create `.github/ISSUE_TEMPLATE/bug_report.md`**

```markdown
---
name: Bug report
about: Report a defect in a composite action
title: "[bug] <action-name>: <short summary>"
labels: ["bug"]
assignees: []
---

## Affected action

<!-- e.g. actions/setup-tools, or "all" -->

## Version pinned

<!-- e.g. @v1, @v1.2.3, @<sha> -->

## Reproduction

```yaml
# Minimal workflow snippet that triggers the bug
```

## Expected behavior

## Actual behavior

## Runner

- OS: <!-- ubuntu-22.04 / macos-14 / windows-2022 / self-hosted -->
- Runner type: <!-- github-hosted / self-hosted -->

## Logs / output

<!-- Paste relevant excerpts. Redact secrets. -->
```

- [ ] **Step 4: Create `.github/ISSUE_TEMPLATE/feature_request.md`**

```markdown
---
name: Feature request
about: Propose a new action or capability
title: "[feat] <short summary>"
labels: ["enhancement"]
assignees: []
---

## Problem

<!-- What can't you do today? What workaround are you using? -->

## Proposed solution

<!-- A new action? A new input on an existing one? Sketch the action.yml shape if helpful. -->

## Alternatives considered

<!-- Other actions, marketplace options, in-line workflow snippets. -->

## Additional context

<!-- Links, screenshots, related issues. -->
```

- [ ] **Step 5: Create `.github/ISSUE_TEMPLATE/config.yml`**

```yaml
blank_issues_enabled: false
# Uncomment if/when GitHub Discussions are enabled:
# contact_links:
#   - name: Discussions
#     url: https://github.com/elioetibr/composite-actions/discussions
#     about: Ask a question or share an idea.
```

- [ ] **Step 6: Create `docs/CONTRIBUTING.md`**

```markdown
# Contributing

Thanks for considering a contribution. This repo is a monorepo of GitHub composite
actions. Read this guide before opening a PR.

## Conventions

- **Commits:** [Conventional Commits](https://www.conventionalcommits.org/) — `feat:`,
  `fix:`, `chore:`, `docs:`, `ci:`, `refactor:`, `test:`. Release-please reads these to
  build the changelog and decide the next version. Commits that don't match are ignored
  for release purposes.
- **Signed commits:** All commits must be GPG-signed (`git commit -S ...`).
- **Loosest tag pinning:** When referencing third-party actions in `uses:`, pin to the
  loosest published tag (e.g. `actions/checkout@v4`, not a SHA). Dependabot keeps these
  fresh.

## Adding a new action

1. **Create the directory.**

    ```bash
    mkdir -p actions/<name>
    ```

2. **Author `actions/<name>/action.yml`.** Skeleton:

    ```yaml
    name: <name>
    description: One-line description of what this action does.
    inputs:
      example:
        description: What this input is for.
        required: false
        default: ""
    outputs:
      example:
        description: What this output is for.
        value: ${{ steps.compute.outputs.value }}
    runs:
      using: composite
      steps:
        - name: Compute
          id: compute
          shell: bash
          run: echo "value=hello" >> "$GITHUB_OUTPUT"
    ```

3. **Author `actions/<name>/README.md`** with action-docs markers:

    ```markdown
    # <name>

    Brief overview.

    ## Inputs

    <!-- action-docs-inputs source="action.yml" -->
    <!-- action-docs-inputs -->

    ## Outputs

    <!-- action-docs-outputs source="action.yml" -->
    <!-- action-docs-outputs -->

    ## Usage

    ```yaml
    - uses: elioetibr/composite-actions/actions/<name>@v1
      with:
        example: value
    ```
    ```

4. **Generate the inputs/outputs tables:**

    ```bash
    npx action-docs --no-banner --source actions/<name>/action.yml --update-readme
    ```

5. **Add a Dependabot directory entry** in `.github/dependabot.yml`:

    ```yaml
    - package-ecosystem: github-actions
      directory: /actions/<name>
      schedule:
        interval: weekly
      open-pull-requests-limit: 5
      labels: ["dependencies", "github-actions"]
    ```

6. **Refresh the root `README.md` actions index** between the marker comments. List the
   new action with a one-line description and a link to its README.

7. **Commit** with `feat: add <name> action` and open a PR.

## Local testing

Composite actions can be smoke-tested with [act](https://github.com/nektos/act). Note
that reusable workflows that consume composite actions have edge cases under act; when
in doubt, push to a branch and run the action in a sandbox workflow.

Example: run `ci.yml` against the current ref:

```bash
act pull_request --workflows .github/workflows/ci.yml
```

## Release flow

- **Open a PR** with Conventional Commit messages.
- **Merge to `main`.** Release-please reads new commits and updates (or opens) a
  release PR titled `chore: release X.Y.Z`.
- **Merge the release PR.** This tags `vX.Y.Z`, creates a GitHub Release, and a
  follow-on step force-updates the floating major tag (`vX`) to the same commit.
- **Consumers using `@v1`** automatically pick up the new release. Consumers pinned
  to `@vX.Y.Z` or a SHA stay on their pin.

## Reporting security issues

See [SECURITY.md](../SECURITY.md). Don't file public issues for vulnerabilities.
```

- [ ] **Step 7: Verify markdown lints**

```bash
markdownlint-cli2 ".github/**/*.md" "docs/CONTRIBUTING.md"
yamllint .github/ISSUE_TEMPLATE/config.yml
```

Expected: both exit 0. If markdownlint flags `MD046/code-block-style` on the CONTRIBUTING.md nested fenced examples (the `action.yml` snippet inside a code block), see Task 3 troubleshooting below.

**Troubleshooting:** If markdownlint flags nested fences in `CONTRIBUTING.md` step 3 (the README skeleton contains an inner ` ```yaml` block), switch the **outer** fence to four backticks:

```text
````markdown
# inner content here can contain ```yaml ... ``` safely
````
```

Re-run the linter after fixing.

- [ ] **Step 8: Commit**

```bash
git add .github/CODEOWNERS .github/PULL_REQUEST_TEMPLATE.md .github/ISSUE_TEMPLATE docs/CONTRIBUTING.md
git commit -S -m "docs: add CODEOWNERS, PR/issue templates, and contributing guide"
```

---

## Task 4: CI gate workflow

**Why:** All downstream tasks assume this exists to validate them. Built before release infrastructure so the very next commit (Task 5) is gated by green CI.

**Files:**

- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Write `.github/workflows/ci.yml`**

```yaml
---
name: ci

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  actionlint:
    name: actionlint
    runs-on: ${{ vars.RUNS_ON_ARM64 || vars.RUNS_ON || 'ubuntu-latest' }}
    steps:
      - uses: actions/checkout@v4
      - name: Run actionlint
        uses: reviewdog/action-actionlint@v1
        with:
          reporter: github-check
          fail_on_error: true
          actionlint_flags: -shellcheck=shellcheck

  yamllint:
    name: yamllint
    runs-on: ${{ vars.RUNS_ON_ARM64 || vars.RUNS_ON || 'ubuntu-latest' }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.x"
      - name: Install yamllint
        run: pip install --upgrade yamllint
      - name: Run yamllint
        run: yamllint .

  markdownlint:
    name: markdownlint
    runs-on: ${{ vars.RUNS_ON_ARM64 || vars.RUNS_ON || 'ubuntu-latest' }}
    steps:
      - uses: actions/checkout@v4
      - name: Run markdownlint-cli2
        uses: DavidAnson/markdownlint-cli2-action@v17
        with:
          globs: |
            **/*.md
            !node_modules
            !.venv

  action-docs-check:
    name: action-docs-check
    runs-on: ${{ vars.RUNS_ON_ARM64 || vars.RUNS_ON || 'ubuntu-latest' }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
      - name: Check action READMEs are in sync with action.yml
        shell: bash
        run: |
          set -euo pipefail
          shopt -s nullglob
          mapfile -t actions < <(find actions -mindepth 2 -maxdepth 2 -name action.yml)
          if (( ${#actions[@]} == 0 )); then
            echo "No actions present; action-docs check is a no-op."
            exit 0
          fi
          fail=0
          for f in "${actions[@]}"; do
            dir="$(dirname "$f")"
            echo "::group::Checking $dir"
            cp "$dir/README.md" "$dir/README.md.bak"
            npx --yes action-docs@^2 --no-banner --source "$f" --update-readme
            if ! diff -q "$dir/README.md" "$dir/README.md.bak" >/dev/null; then
              echo "::error file=$dir/README.md::README.md is out of sync with action.yml. Run: npx action-docs --update-readme --source $f"
              diff -u "$dir/README.md.bak" "$dir/README.md" || true
              fail=1
            fi
            mv "$dir/README.md.bak" "$dir/README.md"
            echo "::endgroup::"
          done
          exit "$fail"

  all-green:
    name: all-green
    runs-on: ${{ vars.RUNS_ON_ARM64 || vars.RUNS_ON || 'ubuntu-latest' }}
    needs: [actionlint, yamllint, markdownlint, action-docs-check]
    if: always()
    steps:
      - name: Verify all required checks passed
        shell: bash
        run: |
          set -euo pipefail
          results='${{ toJSON(needs) }}'
          echo "$results"
          if echo "$results" | grep -Eq '"result":\s*"(failure|cancelled)"'; then
            echo "::error::One or more required checks failed or were cancelled."
            exit 1
          fi
          echo "All required checks passed."
```

- [ ] **Step 2: Validate locally with actionlint**

```bash
actionlint .github/workflows/ci.yml
```

Expected: no output, exit 0. If actionlint flags `shellcheck` being unavailable, install it: `brew install shellcheck` on macOS.

- [ ] **Step 3: Validate yamllint**

```bash
yamllint .github/workflows/ci.yml
```

Expected: no output, exit 0.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml
git commit -S -m "ci: add lint gate workflow (actionlint, yamllint, markdownlint, action-docs)"
```

---

## Task 5: Release infrastructure (release-please config + workflows)

**Files:**

- Create: `.github/release-please-config.json`
- Create: `.release-please-manifest.json`
- Create: `.github/workflows/release.yml`
- Create: `.github/workflows/update-major-tag.yml`

- [ ] **Step 1: Create `.github/release-please-config.json`**

```json
{
  "release-type": "simple",
  "bump-minor-pre-major": true,
  "bump-patch-for-minor-pre-major": true,
  "include-component-in-tag": false,
  "tag-separator": "",
  "packages": {
    ".": {}
  }
}
```

- [ ] **Step 2: Create `.release-please-manifest.json`**

```json
{
  ".": "0.0.0"
}
```

- [ ] **Step 3: Create `.github/workflows/release.yml`**

```yaml
---
name: release

on:
  push:
    branches: [main]

permissions:
  contents: write
  pull-requests: write

concurrency:
  group: release-${{ github.ref }}
  cancel-in-progress: false

jobs:
  release-please:
    name: release-please
    runs-on: ${{ vars.RUNS_ON_ARM64 || vars.RUNS_ON || 'ubuntu-latest' }}
    outputs:
      release_created: ${{ steps.release.outputs.release_created }}
      tag_name: ${{ steps.release.outputs.tag_name }}
      major: ${{ steps.release.outputs.major }}
    steps:
      - id: release
        uses: googleapis/release-please-action@v4
        with:
          config-file: .github/release-please-config.json
          manifest-file: .release-please-manifest.json

  move-major-tag:
    name: move-major-tag
    runs-on: ${{ vars.RUNS_ON_ARM64 || vars.RUNS_ON || 'ubuntu-latest' }}
    needs: release-please
    if: needs.release-please.outputs.release_created == 'true'
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Move floating major tag
        shell: bash
        env:
          TAG_NAME: ${{ needs.release-please.outputs.tag_name }}
          MAJOR: ${{ needs.release-please.outputs.major }}
        run: |
          set -euo pipefail
          : "${TAG_NAME:?missing TAG_NAME}"
          : "${MAJOR:?missing MAJOR}"
          major_tag="v${MAJOR}"
          echo "Moving ${major_tag} -> ${TAG_NAME}"
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git tag -f "${major_tag}" "${TAG_NAME}"
          git push --force origin "refs/tags/${major_tag}"
```

- [ ] **Step 4: Create `.github/workflows/update-major-tag.yml`**

```yaml
---
name: update-major-tag

on:
  workflow_dispatch:
    inputs:
      tag:
        description: "Floating major tag to move (e.g. v1)"
        required: true
        type: string
      sha:
        description: "Commit SHA to point the tag at (defaults to the latest matching vX.Y.Z tag)"
        required: false
        type: string

permissions:
  contents: write

jobs:
  update:
    name: update
    runs-on: ${{ vars.RUNS_ON_ARM64 || vars.RUNS_ON || 'ubuntu-latest' }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Resolve target commit
        id: resolve
        shell: bash
        env:
          TAG: ${{ inputs.tag }}
          SHA: ${{ inputs.sha }}
        run: |
          set -euo pipefail
          if [[ -n "${SHA}" ]]; then
            echo "sha=${SHA}" >> "$GITHUB_OUTPUT"
            exit 0
          fi
          if [[ ! "${TAG}" =~ ^v([0-9]+)$ ]]; then
            echo "::error::Tag must look like 'v<major>' (e.g. v1) when no sha is provided. Got: ${TAG}"
            exit 1
          fi
          major="${BASH_REMATCH[1]}"
          latest="$(git tag --list "v${major}.*.*" --sort=-version:refname | head -n1)"
          if [[ -z "${latest}" ]]; then
            echo "::error::No semver tag found matching v${major}.x.y"
            exit 1
          fi
          sha="$(git rev-list -n1 "${latest}")"
          echo "Latest semver for major v${major} is ${latest} (${sha})"
          echo "sha=${sha}" >> "$GITHUB_OUTPUT"
      - name: Move tag
        shell: bash
        env:
          TAG: ${{ inputs.tag }}
          SHA: ${{ steps.resolve.outputs.sha }}
        run: |
          set -euo pipefail
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git tag -f "${TAG}" "${SHA}"
          git push --force origin "refs/tags/${TAG}"
          echo "Moved ${TAG} -> ${SHA}"
```

- [ ] **Step 5: Validate workflows**

```bash
actionlint .github/workflows/release.yml .github/workflows/update-major-tag.yml
yamllint .github/workflows/release.yml .github/workflows/update-major-tag.yml
```

Expected: no output, exit 0.

- [ ] **Step 6: Validate JSON configs**

```bash
python3 -c "import json; json.load(open('.github/release-please-config.json'))"
python3 -c "import json; json.load(open('.release-please-manifest.json'))"
```

Expected: no output, exit 0 (both parse).

- [ ] **Step 7: Commit**

```bash
git add .github/release-please-config.json .release-please-manifest.json \
        .github/workflows/release.yml .github/workflows/update-major-tag.yml
git commit -S -m "ci: add release-please flow and floating major tag mover"
```

---

## Task 6: Dependabot configuration

**Files:**

- Create: `.github/dependabot.yml`

- [ ] **Step 1: Create `.github/dependabot.yml`**

```yaml
---
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
      day: monday
      time: "06:00"
      timezone: America/Sao_Paulo
    open-pull-requests-limit: 5
    labels:
      - dependencies
      - github-actions
    commit-message:
      prefix: chore
      include: scope
    # Note: when adding a new action under actions/<name>/, append a sibling
    # entry below with `directory: /actions/<name>` so its action.yml `uses:`
    # references stay up to date. The CONTRIBUTING guide documents this step.
```

- [ ] **Step 2: Validate**

```bash
yamllint .github/dependabot.yml
actionlint .github/dependabot.yml || true  # actionlint doesn't lint dependabot.yml; ignore
```

Expected: yamllint exit 0.

- [ ] **Step 3: Commit**

```bash
git add .github/dependabot.yml
git commit -S -m "ci: add Dependabot config for github-actions ecosystem"
```

---

## Task 7: Actions namespace placeholder

**Why:** `git` doesn't track empty directories. A `.keep` file pins the namespace so the layout is visible from day one and CI's `action-docs-check` can iterate `actions/*/action.yml` without erroring on a missing directory.

**Files:**

- Create: `actions/.keep`

- [ ] **Step 1: Create `actions/.keep`**

```text
# Placeholder so the actions/ directory is tracked.
# Add new composite actions as sibling directories: actions/<name>/{action.yml,README.md}
# See docs/CONTRIBUTING.md for the full recipe.
```

- [ ] **Step 2: Commit**

```bash
git add actions/.keep
git commit -S -m "chore: reserve actions/ namespace with placeholder"
```

---

## Task 8: Final verification

**Why:** Run every linter against the full scaffolded repo to confirm nothing slipped past the per-task checks. Mirrors what CI will do on the first push.

- [ ] **Step 1: Full markdownlint pass**

```bash
markdownlint-cli2 "**/*.md" "#node_modules" "#.venv" "#docs/superpowers"
```

Expected: exit 0, no warnings. The `#docs/superpowers` exclusion skips the gitignored spec/plan docs.

- [ ] **Step 2: Full yamllint pass**

```bash
yamllint .
```

Expected: exit 0, no output.

- [ ] **Step 3: Full actionlint pass**

```bash
actionlint
```

Expected: exit 0, no output. Actionlint discovers `.github/workflows/*.yml` automatically.

- [ ] **Step 4: Verify JSON configs**

```bash
python3 -c "import json; json.load(open('.github/release-please-config.json'))"
python3 -c "import json; json.load(open('.release-please-manifest.json'))"
```

Expected: both parse cleanly.

- [ ] **Step 5: Verify final layout matches spec §4**

```bash
find . \
  -path ./.git -prune -o \
  -path ./node_modules -prune -o \
  -path ./.venv -prune -o \
  -path ./docs/superpowers -prune -o \
  -type f -print | sort
```

Expected (order may vary; comparison is set-equality of paths excluding the pruned directories):

```text
./.editorconfig
./.github/CODEOWNERS
./.github/ISSUE_TEMPLATE/bug_report.md
./.github/ISSUE_TEMPLATE/config.yml
./.github/ISSUE_TEMPLATE/feature_request.md
./.github/PULL_REQUEST_TEMPLATE.md
./.github/dependabot.yml
./.github/release-please-config.json
./.github/workflows/ci.yml
./.github/workflows/release.yml
./.github/workflows/update-major-tag.yml
./.gitignore
./.markdownlint.yaml
./.release-please-manifest.json
./.yamllint.yaml
./LICENSE
./LICENSE-APACHE-2.0
./LICENSE-MIT
./README.md
./SECURITY.md
./actions/.keep
./docs/CONTRIBUTING.md
```

- [ ] **Step 6: Push to remote**

```bash
git log --oneline -10
git push origin main
```

Expected: 7 new commits pushed (Tasks 1–7). Confirm the GitHub UI shows the `ci` workflow running on the push.

- [ ] **Step 7: Confirm first CI run on `main` is green**

Watch the run in the GitHub UI or:

```bash
gh run watch
```

Expected: all four lint jobs + `all-green` pass. `action-docs-check` reports "No actions present; action-docs check is a no-op." `release.yml` runs and release-please reports "no release created" (correct — we're at `0.0.0` and have only `chore:`, `docs:`, `ci:` commits, none of which produce a release).

---

## Acceptance criteria (from spec §13)

After Task 8 step 7 passes, the following acceptance criteria from the spec are satisfied:

- ✅ Every directory path and file listed in spec §4 exists.
- ✅ A `chore:` push to `main` triggers `ci.yml` with all four lint jobs + `all-green` passing.
- ✅ `release.yml` runs without error; release-please reports no releasable changes.
- ✅ `markdownlint` and `yamllint` pass cleanly against the scaffolded files.
- ✅ `LICENSE`, `LICENSE-APACHE-2.0`, `LICENSE-MIT` are referenced from `README.md`.
- ✅ `actionlint` accepts all three workflow files.

## Self-review notes

- **Coverage:** Each spec section maps to a task — §4 layout (all tasks), §5 release (Task 5), §6 CI (Task 4), §7 release (Task 5), §8 configs (Tasks 1, 5, 6), §9 hygiene (Tasks 2, 3, 7).
- **No placeholders:** Every step contains the actual file contents or the exact command to run.
- **Type/name consistency:** The CI aggregator job name (`all-green`) is referenced consistently. The floating-major-tag move uses `${TAG_NAME}` and `${MAJOR}` from release-please outputs in both `release.yml` and (independently sourced) `update-major-tag.yml`. The actions-index markers (`actions-index:start` / `actions-index:end`) match between `README.md` (Task 2) and `CONTRIBUTING.md` (Task 3 step 6).
