# checkout-as-bot

Generate a GitHub App installation token, check out the repository using that
token, and configure git as `github-actions[bot]`. Returns the token as a step
output for downstream uses (e.g. authenticated API calls, release-please).

Useful when enterprise policy blocks the default `GITHUB_TOKEN` from creating
pull requests or pushing to protected branches — the App's installation token
acts as a separate identity that retains those permissions.

<!-- action-docs-inputs source="action.yml" -->

<!-- action-docs-outputs source="action.yml" -->

## Usage

```yaml
- uses: elioetibr/composite-actions/checkout-as-bot@v0
  id: setup
  with:
    client-id: ${{ vars.CLIENT_ID }}
    private-key: ${{ secrets.PRIVATE_KEY }}

# downstream step that needs the App token
- env:
    GH_TOKEN: ${{ steps.setup.outputs.token }}
  run: gh api repos/${{ github.repository }}/pulls
```
