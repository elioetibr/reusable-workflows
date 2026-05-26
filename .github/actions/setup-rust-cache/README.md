# setup-rust-cache

Set up optimized caching for Rust projects (rustup, cargo registry, target).

<!-- action-docs-inputs source="action.yml" -->
## Inputs

| name | description | required | default |
| --- | --- | --- | --- |
| `cache-key-suffix` | <p>Additional suffix for cache key specificity</p> | `false` | `""` |
| `toolchain` | <p>Rust toolchain version</p> | `false` | `stable` |
| `cache-target` | <p>Whether to cache target directory</p> | `false` | `true` |
<!-- action-docs-inputs source="action.yml" -->

<!-- action-docs-outputs source="action.yml" -->

<!-- action-docs-outputs source="action.yml" -->

## Usage

```yaml
- uses: elioetibr/composite-actions/setup-rust-cache@v0
  with:
    toolchain: stable
```
