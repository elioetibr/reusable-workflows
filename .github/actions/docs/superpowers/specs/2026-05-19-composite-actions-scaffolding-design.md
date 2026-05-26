# Composite Actions Repository Scaffolding — Design

- **Date:** 2026-05-19
- **Author:** Elio Severo Junior
- **Status:** Draft — awaiting review

## 1. Purpose

Establish a monorepo skeleton for `elioetibr/composite-actions` that hosts multiple GitHub composite actions under one repository, with shared CI quality gates, automated releases, and contribution conventions. No concrete actions are scaffolded yet — only the structure, tooling, and documentation needed to add them.

## 2. Goals

- Provide a single home for related composite actions, each independently consumable via `uses: elioetibr/composite-actions/actions/<name>@v1`.
- Enforce consistent quality on every PR: action.yml correctness, YAML/Markdown style, shell safety, README/inputs-outputs sync.
- Automate version management with one repo-wide semantic version and a floating major tag (`v1`) that consumers can pin to.
- Document the "add a new action" workflow so future actions follow a predictable pattern.
- Match repository-wide preferences: dual Apache-2.0/MIT licensing, loosest-tag pinning for `uses:` references, MD022/MD032 markdown hygiene, GPG-signed commits, no Claude co-authorship lines.

## 3. Non-Goals

- Scaffolding any concrete action implementations. The `actions/` directory will contain only a `.keep` placeholder.
- Setting up `act`-based local testing infrastructure beyond a brief note in `CONTRIBUTING.md`.
- Creating an organization-level reusable workflow library — this repo is scoped to composite actions only.
- Branch protection configuration (lives in GitHub UI/Terraform, not in the repo).

## 4. Repository Layout

```text
composite-actions/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                          # PR gate aggregator
│   │   ├── release.yml                     # release-please flow
│   │   └── update-major-tag.yml            # manual floating-tag mover
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   ├── feature_request.md
│   │   └── config.yml
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── CODEOWNERS                          # * @elioetibr
│   ├── dependabot.yml                      # github-actions ecosystem, weekly
│   └── release-please-config.json          # single-package, repo-wide version
├── actions/
│   └── .keep                               # placeholder; real actions added later
├── docs/
│   ├── CONTRIBUTING.md
│   └── superpowers/
│       └── specs/
│           └── 2026-05-19-composite-actions-scaffolding-design.md
├── .editorconfig
├── .gitignore
├── .markdownlint.yaml
├── .yamllint.yaml
├── .release-please-manifest.json           # { ".": "0.0.0" }
├── LICENSE                                  # pointer (already present)
├── LICENSE-APACHE-2.0                       # full text (already present)
├── LICENSE-MIT                              # full text (already present)
├── SECURITY.md
└── README.md
```

## 5. Versioning & Release Strategy

**Repo-wide single version** — every release bumps one number that applies to all actions. Tradeoff: simplicity over per-action independence.

- Tags: `v1.2.3` (semver) and floating `v1` (major).
- Consumers pin to `@v1` (loosest tag preference); patch fixes flow in automatically.
- `release-please` opens a release PR from Conventional Commits on `main`; merging that PR creates the tag + GitHub Release. A follow-on workflow step force-updates the floating major tag to the same commit.
- A manually triggered `update-major-tag.yml` (workflow_dispatch with `tag` input) exists as a safety net if the auto-update step ever fails.
- Pre-1.0: `bump-minor-pre-major: true` in `release-please-config.json` so breaking changes bump minor, not major, until the first `v1.0.0`.

## 6. CI Workflow Design (`.github/workflows/ci.yml`)

**Triggers:** `pull_request` to any branch, `push` to `main`.

**Concurrency:** group `ci-${{ github.ref }}`, `cancel-in-progress: true` — superseded PR runs cancel.

**Jobs (run in parallel):**

| Job ID | Action(s) used | Scope | Fails on |
| --- | --- | --- | --- |
| `actionlint` | `rhysd/actionlint` (with shellcheck enabled) | `**/action.yml`, `.github/workflows/**` | Syntax, expression, or inline-bash issues |
| `yamllint` | `pip install yamllint` then `yamllint .` | All `*.yml` / `*.yaml` | Violations from `.yamllint.yaml` |
| `markdownlint` | `DavidAnson/markdownlint-cli2-action` (loosest current major) | All `*.md` | MD022 / MD032 + standard rules |
| `action-docs-check` | `npx action-docs --no-banner` per action | `actions/*/action.yml` | README inputs/outputs table drift |

**Aggregator job `all-green`** depends on all the above with `if: always()` and asserts none failed. Branch protection only requires `ci / all-green`, so adding a new job in the future doesn't require updating protection rules.

`action-docs-check` is non-mutating in CI — contributors run `npx action-docs --update-readme` locally and commit. No bot push-backs onto PRs.

## 7. Release Workflow Design

### `.github/workflows/release.yml`

- **Trigger:** `push` to `main`.
- **Permissions:** `contents: write`, `pull-requests: write`.
- **Step 1 — release-please:** `googleapis/release-please-action`. Reads commits, opens or updates the release PR. On release PR merge, creates tag `vX.Y.Z` and a GitHub Release.
- **Step 2 — move floating major tag:** runs only when `steps.release.outputs.release_created == 'true'`. Force-updates `v${major}` (extracted from the new tag) to point at the new commit and pushes it.

### `.github/workflows/update-major-tag.yml`

- **Trigger:** `workflow_dispatch` only.
- **Inputs:** `tag` (e.g. `v1`), `sha` (commit to point at — defaults to the SHA of the latest matching `vX.Y.Z` tag).
- **Action:** force-updates the major tag. Manual safety net; not part of the happy path.

## 8. Configuration Files

### `.editorconfig`

UTF-8, LF line endings, insert final newline, trim trailing whitespace. 2-space indent for YAML, JSON, Markdown. Tab indent for Makefiles.

### `.gitignore`

Extends the empty starting file with: `.idea/`, `.DS_Store`, `node_modules/`, `.venv/`, `*.log`, `.terraform/`. (Honors global "ignore .idea / .venv / .terraform" preferences.)

### `.markdownlint.yaml`

- `default: true`
- `MD013: false` (line length — too noisy on tables and URLs)
- `MD022: true` (blanks around headings — explicit per user preference)
- `MD032: true` (blanks around lists — explicit per user preference)
- `MD033: false` (allow inline HTML for `<details>` / action-docs markers)
- `MD041: false` (first line doesn't need to be a top-level heading — action-docs READMEs start with markers)

### `.yamllint.yaml`

- `extends: default`
- `rules.line-length.max: 200`
- `rules.truthy.check-keys: false` (so workflow `on:` keys pass)
- `rules.comments-indentation: disable`
- `rules.document-start: disable`

### `.github/dependabot.yml`

- `version: 2`
- One `package-ecosystem: github-actions` entry per directory:
  - `/` (covers `.github/workflows/*`)
  - One entry per `actions/<name>/` will be added when each action is created (documented in CONTRIBUTING).
- `schedule.interval: weekly`
- `open-pull-requests-limit: 5`
- `labels: ["dependencies", "github-actions"]`

Dependabot raises tag bumps (e.g. `actions/checkout@v6` → `v7`); per the user's global preference, we never pin to SHAs when a tag is available.

### `.github/release-please-config.json`

```json
{
  "release-type": "simple",
  "bump-minor-pre-major": true,
  "bump-patch-for-minor-pre-major": true,
  "include-component-in-tag": false,
  "packages": {
    ".": {}
  }
}
```

### `.release-please-manifest.json`

```json
{ ".": "0.0.0" }
```

## 9. Repository Hygiene Files

### `.github/CODEOWNERS`

```text
* @elioetibr
```

### `.github/PULL_REQUEST_TEMPLATE.md`

Sections:

- **What** — short description
- **Why** — motivation / linked issue
- **Action(s) affected** — list
- **Testing** — how was this validated
- **Breaking change?** — checkbox + migration notes if checked
- **Docs updated?** — checkbox (README, CONTRIBUTING, action README)

### `.github/ISSUE_TEMPLATE/`

- `bug_report.md` — affected action, minimal reproduction workflow snippet, expected vs actual, runner OS/version, action version pinned.
- `feature_request.md` — problem statement, proposed solution, alternatives considered.
- `config.yml` — `blank_issues_enabled: false`. Optional `contact_links` entry pointing to Discussions left commented-out as a future toggle.

### `SECURITY.md`

- Reporting channel: GitHub private vulnerability reporting (preferred) or email.
- Supported versions: latest `v1.x` only (table updated per major).
- Disclosure timeline: 90 days from acknowledgement.

### `README.md`

Sections:

1. **Overview** — what the repo is.
2. **Available actions** — index between markers (`<!-- actions-index:start -->` / `<!-- actions-index:end -->`); empty until first action lands. Refreshed manually as part of the "add a new action" recipe in `CONTRIBUTING.md` (no auto-generation tooling — kept simple to avoid another CI check).
3. **Usage** — generic pattern: `uses: elioetibr/composite-actions/actions/<name>@v1`.
4. **Version pinning** — recommended `@v1` (auto patch updates), document `@v1.2.3` (frozen) and `@<sha>` (only when no tag exists) as escape hatches. Mirrors the user's global "loosest tag" rule.
5. **Contributing** — link to `docs/CONTRIBUTING.md`.
6. **Security** — link to `SECURITY.md`.
7. **License** — "Dual-licensed under Apache-2.0 OR MIT — see [LICENSE](LICENSE), [LICENSE-APACHE-2.0](LICENSE-APACHE-2.0), [LICENSE-MIT](LICENSE-MIT)."

### `docs/CONTRIBUTING.md`

Sections:

1. **Adding a new action** — step-by-step recipe:
   1. Create `actions/<name>/action.yml` with `name`, `description`, `inputs`, `outputs`, `runs.using: composite`.
   2. Create `actions/<name>/README.md` with `<!-- action-docs-* -->` markers.
   3. Run `npx action-docs --update-readme actions/<name>/action.yml`.
   4. Add a Dependabot directory entry for `/actions/<name>`.
   5. Refresh the root README actions index.
2. **Commit conventions** — Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, etc.) — required for release-please changelog generation. All commits GPG-signed.
3. **Local testing** — brief `act` usage example, with caveats (composite actions inside reusable workflows have quirks under act).
4. **Release flow** — explanation of the release-please PR lifecycle and the floating major tag.

## 10. Dependencies on External Tooling

- `rhysd/actionlint` — pinned to loosest available major tag.
- `googleapis/release-please-action` — pinned to loosest available major tag.
- `DavidAnson/markdownlint-cli2-action` — pinned to loosest available major tag.
- `npx action-docs` — invoked via Node setup (no committed `package.json`; npx pulls latest at run time, scoped to a major via `action-docs@^X`).
- `pip install yamllint` — installs latest at run time inside the job.

All version pins follow the user's loosest-tag rule. Dependabot watches the workflow files and raises bumps.

## 11. Risks & Tradeoffs

| Risk | Mitigation |
| --- | --- |
| Repo-wide versioning bumps unrelated actions on every release | Accepted tradeoff for simplicity; revisit if action drift becomes painful and switch to per-action tagging. |
| Conventional Commits is a new constraint | Documented in CONTRIBUTING; release-please's PR-based flow surfaces formatting issues early (commit titles can be edited at squash time). |
| `action-docs-check` blocks PRs on stale READMEs | Recipe in CONTRIBUTING is one command; failure message will name the file to update. |
| `npx action-docs` at runtime is a soft pin | Acceptable for a check tool; Dependabot doesn't watch npx, but a major-version bump in action-docs will surface in CI failures. Can tighten to a committed `package.json` if instability shows up. |
| Floating major tag force-push during release | Only the release workflow has write to tags; CODEOWNERS + branch protection (set in UI) gate the workflow itself. |

## 12. Open Questions

None remaining as of approval of Sections 1–3. Recorded for completeness — to be resolved when the first real action is added:

- Whether to add a per-action `tests/` convention (e.g. workflow that exercises each action against a matrix of runners).
- Whether to publish to the GitHub Marketplace per action (requires per-action root `action.yml`, which is incompatible with the monorepo layout — would require a sibling release repo per action if pursued).

## 13. Acceptance Criteria

- All directory paths and files in Section 4 exist with the contents described in Sections 5–9.
- `git push` to `main` of a `chore: scaffold repo` commit triggers `ci.yml` and all four lint jobs (`actionlint`, `yamllint`, `markdownlint`, `action-docs-check`) pass with zero actions present.
- The `release.yml` workflow runs without error on push to `main`; release-please reports "no releasable changes" (expected for a `chore:` commit at `0.0.0`).
- `markdownlint` and `yamllint` pass cleanly against the scaffolded files.
- `LICENSE`, `LICENSE-APACHE-2.0`, `LICENSE-MIT` are referenced from the root `README.md` license section.
- `actionlint` accepts all three workflow files (`ci.yml`, `release.yml`, `update-major-tag.yml`).
