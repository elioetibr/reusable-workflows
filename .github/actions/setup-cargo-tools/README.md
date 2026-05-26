# setup-cargo-tools

Cache and install cargo tools (e.g. `cargo-audit`, `cargo-llvm-cov`) across CI runs.

<!-- action-docs-inputs source="action.yml" -->
## Inputs

| name | description | required | default |
| --- | --- | --- | --- |
| `tools` | <p>Space-separated list of tools to install and cache</p> | `true` | `""` |
| `arch` | <p>Architecture (x86_64, aarch64, etc.)</p> | `false` | `x86_64` |
<!-- action-docs-inputs source="action.yml" -->

<!-- action-docs-outputs source="action.yml" -->

<!-- action-docs-outputs source="action.yml" -->

## Usage

```yaml
- uses: elioetibr/composite-actions/setup-cargo-tools@v0
  with:
    tools: cargo-audit cargo-llvm-cov
```
