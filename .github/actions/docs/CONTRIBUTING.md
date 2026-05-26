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
  loosest published tag (e.g. `actions/checkout@v6`, not a SHA). Dependabot keeps these
  fresh.

## Adding a new action

1. **Create the directory.**

    ```bash
    mkdir -p <name>
    ```

2. **Author `<name>/action.yml`.** Skeleton:

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

3. **Author `<name>/README.md`** with action-docs markers:

    ````markdown
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
    - uses: elioetibr/composite-actions/<name>@v1
      with:
        example: value
    ```
    ````

4. **Generate the inputs/outputs tables:**

    ```bash
    npx action-docs@^2 --no-banner --source <name>/action.yml --update-readme
    ```

5. **Add a Dependabot directory entry** in `.github/dependabot.yml`:

    ```yaml
    - package-ecosystem: github-actions
      directory: /<name>
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

Versioning is computed by [GitVersion](https://gitversion.net/) (config in `GitVersion.yml`). release-please handles the PR ceremony, changelog, and GitHub Release UI but does **not** decide the version — GitVersion does, via the `release-as` input.

1. **Open a PR** with Conventional Commit messages. GitVersion's bump rules (see `GitVersion.yml`):
   - `feat:` → minor bump
   - `fix:` / `perf:` → patch bump
   - `BREAKING CHANGE:` or `<type>!:` → major bump
   - `chore:`, `docs:`, `ci:`, `style:`, `refactor:`, `test:`, `build:`, `revert:` → no bump
2. **Merge to `main`.** The release workflow runs GitVersion to compute `MajorMinorPatch` (e.g., `1.2.3`) and `FullSemVer` (e.g., `1.2.3-47`). release-please opens (or updates) a release PR titled `chore: release 1.2.3`.
3. **Merge the release PR.** This triggers:
   - release-please creates tag `v1.2.3` and the GitHub Release.
   - A follow-on step creates the **immutable annotated tag `v1.2.3-47`** (using GitVersion's `FullSemVer`) and force-moves the floating tags `v1` and `v1.2` to point at the release commit.
4. **Consumer pin behavior:**
   - `@v1` and `@v1.2` auto-move to the new release.
   - `@v1.2.3` is created by release-please and stays at the release commit.
   - `@v1.2.3-47` is immutable and never moves.

If a floating tag ever needs to be re-pointed manually (e.g., to recover from a misfire), use the `update-floating-tag` workflow (`workflow_dispatch`, accepts `vN` or `vN.M`).

## Reporting security issues

See [SECURITY.md](../SECURITY.md). Don't file public issues for vulnerabilities.
