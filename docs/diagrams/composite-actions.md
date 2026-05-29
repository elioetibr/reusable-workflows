# Composite Actions Documentation

## Overview

This repository uses composite actions from [viafoura/composite-actions@v3](https://github.com/viafoura/composite-actions) that encapsulate common CI/CD patterns used across all build workflows. These actions follow the DRY principle and provide a single source of truth for shared functionality.

> **Note:** The composite actions have been migrated from `.github/actions/` in this repository to the centralized `viafoura/composite-actions` repository and are now available at version `v3`.

## Architecture

```mermaid
flowchart TB
    subgraph workflows["Workflows Using Composite Actions"]
        UW["build-multi-arch.yml"]
        JW["java-build-multi-arch.yml"]
        DW["docker-build-multi-arch.yml"]
        HW["helm-version-tag-updater.yml"]
    end

    subgraph actions["Composite Actions (viafoura/composite-actions@v3)"]
        CA1["aws-ecr-setup"]
        CA2["docker-buildx-setup"]
        CA3["github-auth-checkout"]
        CA4["gitversion-calculate"]
    end

    subgraph external["External Actions"]
        EA1["aws-actions/configure-aws-credentials"]
        EA2["aws-actions/amazon-ecr-login"]
        EA3["docker/setup-buildx-action"]
        EA4["actions/create-github-app-token"]
        EA5["actions/checkout"]
        EA6["gittools/actions/gitversion"]
        EA7["actions/cache"]
    end

    JW --> UW
    DW --> UW

    UW --> CA1
    UW --> CA2
    UW --> CA3
    UW --> CA4

    HW --> CA3

    CA1 --> EA1
    CA1 --> EA2
    CA2 --> EA3
    CA3 --> EA4
    CA3 --> EA5
    CA4 --> EA6
    CA4 --> EA7

    style workflows fill:#e3f2fd
    style actions fill:#c8e6c9
    style external fill:#fff3e0
```

## Action Details

### 1. aws-ecr-setup

Configures AWS credentials using OIDC and logs into Amazon ECR.

```mermaid
flowchart LR
    subgraph inputs["Inputs"]
        I1["aws-account-id"]
        I2["aws-region"]
        I3["aws-role-name"]
        I4["role-duration-seconds"]
    end

    subgraph action["aws-ecr-setup"]
        A1["Configure AWS Credentials<br/>(OIDC)"]
        A2["Login to ECR"]
        A1 --> A2
    end

    subgraph outputs["Outputs"]
        O1["aws-access-key-id"]
        O2["aws-secret-access-key"]
        O3["aws-session-token"]
        O4["registry"]
    end

    inputs --> action
    action --> outputs

    style action fill:#bbdefb
```

#### Inputs

| Input | Required | Default | Description |
| ----- | -------- | ------- | ----------- |
| `aws-account-id` | Yes | - | AWS Account ID |
| `aws-region` | No | `us-east-1` | AWS Region |
| `aws-role-name` | No | `github-actions-role` | IAM role name for OIDC |
| `role-duration-seconds` | No | `1800` | Role session duration |

#### Outputs

| Output | Description |
| ------ | ----------- |
| `aws-access-key-id` | AWS Access Key ID |
| `aws-secret-access-key` | AWS Secret Access Key |
| `aws-session-token` | AWS Session Token |
| `registry` | ECR Registry URL |

#### Usage Example

```yaml
- name: Setup AWS and ECR
  uses: elioetibr/composite-actions/.github/actions/aws-ecr-setup@main
  with:
    aws-account-id: ${{ vars.AWS_CICD_ACCOUNT_ID }}
    aws-region: ${{ vars.AWS_REGION }}
    aws-role-name: github-actions-role
```

---

### 2. docker-buildx-setup

Configures Docker BuildX with an ECR-hosted BuildKit image for improved performance.

```mermaid
flowchart LR
    subgraph inputs["Inputs"]
        I1["buildkit-image"]
    end

    subgraph action["docker-buildx-setup"]
        A1["Setup Docker BuildX<br/>with ECR BuildKit"]
    end

    subgraph result["Result"]
        R1["BuildX configured<br/>with custom builder"]
    end

    inputs --> action
    action --> result

    style action fill:#c8e6c9
```

#### Inputs

| Input | Required | Default | Description |
| ----- | -------- | ------- | ----------- |
| `buildkit-image` | No | ECR mirror | Docker BuildKit image URL |

#### Usage Example

```yaml
- name: Setup Docker BuildX
  uses: elioetibr/composite-actions/.github/actions/docker-buildx-setup@main
  with:
    buildkit-image: ${{ vars.AWS_CICD_ACCOUNT_ID }}.dkr.ecr.${{ vars.AWS_REGION }}.amazonaws.com/moby/buildkit:buildx-stable-1
```

---

### 3. github-auth-checkout

Generates a GitHub App token and checks out the repository with proper authentication.

```mermaid
flowchart LR
    subgraph inputs["Inputs"]
        I1["app-id"]
        I2["private-key"]
        I3["owner"]
        I4["repositories"]
        I5["fetch-depth"]
        I6["fetch-tags"]
    end

    subgraph action["github-auth-checkout"]
        A1["Set Bot Identity"]
        A2["Generate App Token"]
        A3["Checkout Repository"]
        A1 --> A2 --> A3
    end

    subgraph outputs["Outputs"]
        O1["token"]
        O2["bot-name"]
        O3["bot-email"]
    end

    inputs --> action
    action --> outputs

    style action fill:#fff9c4
```

#### Inputs

| Input | Required | Default | Description |
| ----- | -------- | ------- | ----------- |
| `app-id` | Yes | - | GitHub App ID |
| `private-key` | Yes | - | GitHub App private key |
| `owner` | No | Current owner | Repository owner |
| `repositories` | No | Current repo | Comma-separated repository list |
| `fetch-depth` | No | `0` | Git fetch depth |
| `fetch-tags` | No | `true` | Whether to fetch tags |

#### Outputs

| Output | Description |
| ------ | ----------- |
| `token` | Generated GitHub App token |
| `bot-name` | Bot username for commits |
| `bot-email` | Bot email for commits |

#### Usage Example

```yaml
- name: Checkout with Auth
  id: checkout
  uses: elioetibr/composite-actions/.github/actions/github-auth-checkout@main
  with:
    app-id: ${{ vars.GH_APP_ID }}
    private-key: ${{ secrets.PRIVATE_KEY }}
    fetch-depth: 0
    fetch-tags: true

- name: Use Token
  run: |
    git config user.name "${{ steps.checkout.outputs.bot-name }}"
    git config user.email "${{ steps.checkout.outputs.bot-email }}"
```

---

### 4. gitversion-calculate

Calculates semantic version using GitVersion with caching for improved performance.

```mermaid
flowchart LR
    subgraph inputs["Inputs"]
        I1["version-spec"]
    end

    subgraph action["gitversion-calculate"]
        A1["Restore Cache"]
        A2["Setup GitVersion"]
        A3["Execute GitVersion"]
        A4["Save Cache"]
        A1 --> A2 --> A3 --> A4
    end

    subgraph outputs["Outputs"]
        O1["version"]
        O2["semVer"]
        O3["shortSha"]
        O4["sha"]
    end

    inputs --> action
    action --> outputs

    style action fill:#f8bbd9
```

#### Inputs

| Input | Required | Default | Description |
| ----- | -------- | ------- | ----------- |
| `version-spec` | No | `5.x` | GitVersion version specification |

#### Outputs

| Output | Description |
| ------ | ----------- |
| `version` | Major.Minor.Patch version (e.g., `1.2.3`) |
| `semVer` | Full semantic version (e.g., `1.2.3-alpha.1`) |
| `shortSha` | Short commit SHA (e.g., `abc1234`) |
| `sha` | Full commit SHA |

#### Usage Example

```yaml
- name: Calculate Version
  id: version
  uses: elioetibr/composite-actions/.github/actions/gitversion-calculate@main
  with:
    version-spec: '5.x'

- name: Use Version
  run: |
    echo "Version: ${{ steps.version.outputs.version }}"
    echo "SemVer: ${{ steps.version.outputs.semVer }}"
    echo "Short SHA: ${{ steps.version.outputs.shortSha }}"
```

---

## Usage by Job

The following diagram shows which jobs use which composite actions:

```mermaid
flowchart TB
    subgraph build_jobs["Build Workflow Jobs"]
        J1["checks"]
        J2["version"]
        J3["gradle-build"]
        J4["docker-build"]
        J5["manifest"]
        J6["sonarcloud-updates"]
    end

    subgraph helm_jobs["Helm Version Updater Jobs"]
        H1["validate-and-update"]
    end

    subgraph actions["Composite Actions (viafoura/composite-actions@v3)"]
        CA1["aws-ecr-setup"]
        CA2["docker-buildx-setup"]
        CA3["github-auth-checkout"]
        CA4["gitversion-calculate"]
    end

    J1 --> CA1
    J2 --> CA3
    J2 --> CA4
    J3 --> CA1
    J3 --> CA3
    J4 --> CA1
    J4 --> CA2
    J4 --> CA3
    J5 --> CA1
    J5 --> CA2
    J5 --> CA3
    J6 --> CA1
    J6 --> CA3

    H1 --> CA3

    style CA1 fill:#bbdefb
    style CA2 fill:#c8e6c9
    style CA3 fill:#fff9c4
    style CA4 fill:#f8bbd9
    style helm_jobs fill:#e8f5e9
```

## Action Usage Matrix

### Build Workflows (build-multi-arch.yml)

| Job | aws-ecr-setup | docker-buildx-setup | github-auth-checkout | gitversion-calculate |
| --- | :-----------: | :-----------------: | :------------------: | :------------------: |
| checks | ✅ | - | - | - |
| version | - | - | ✅ | ✅ |
| gradle-build | ✅ | - | ✅ | - |
| docker-build | ✅ | ✅ | ✅ | - |
| manifest | ✅ | ✅ | ✅ | - |
| sonarcloud-updates | ✅ | - | ✅ | - |

### Other Workflows

| Workflow | aws-ecr-setup | docker-buildx-setup | github-auth-checkout | gitversion-calculate |
| -------- | :-----------: | :-----------------: | :------------------: | :------------------: |
| helm-version-tag-updater | - | - | ✅ | - |

## Benefits of Composite Actions

```mermaid
flowchart TB
    subgraph before["Before (Duplicated Code)"]
        B1["docker-build-multi-arch.yml<br/>616 lines"]
        B2["java-build-multi-arch.yml<br/>797 lines"]
        B3["Total: ~1413 lines<br/>~70% duplication"]
    end

    subgraph after["After (Composite Actions)"]
        A1["build-multi-arch.yml<br/>731 lines"]
        A2["Wrapper workflows<br/>~410 lines"]
        A3["Composite actions<br/>~200 lines"]
        A4["Total: ~1341 lines<br/>~0% duplication"]
    end

    subgraph benefits["Key Benefits"]
        K1["Single Source of Truth"]
        K2["Easy Maintenance"]
        K3["Consistent Behavior"]
        K4["Reduced Errors"]
        K5["Better Testability"]
    end

    before --> after
    after --> benefits

    style before fill:#ffcdd2
    style after fill:#c8e6c9
    style benefits fill:#e3f2fd
```

### Summary

| Metric | Before | After | Improvement |
| ------ | ------ | ----- | ----------- |
| AWS/ECR setup code | 6 copies | 1 action | 83% reduction |
| Docker BuildX setup | 4 copies | 1 action | 75% reduction |
| GitHub auth/checkout | 7+ copies | 1 action | 86% reduction |
| GitVersion setup | 2 copies | 1 action | 50% reduction |
| Total duplication | ~70% | ~0% | 70% reduction |

## File Structure

```text
.github/
└── workflows/
    ├── build-multi-arch.yml         # Unified core workflow
    ├── docker-build-multi-arch.yml  # Docker wrapper
    ├── java-build-multi-arch.yml    # Java wrapper
    └── helm-version-tag-updater.yml # Helm version updater
```

The composite actions are now hosted in [viafoura/composite-actions@v3](https://github.com/viafoura/composite-actions):

- `elioetibr/composite-actions/.github/actions/aws-ecr-setup@main` - AWS OIDC + ECR login
- `elioetibr/composite-actions/.github/actions/docker-buildx-setup@main` - Docker BuildX configuration
- `elioetibr/composite-actions/.github/actions/github-auth-checkout@main` - GitHub App auth + checkout
- `elioetibr/composite-actions/.github/actions/gitversion-calculate@main` - GitVersion with caching

## Contributing

When modifying composite actions:

1. **Test Changes**: Ensure changes work with both `docker` and `java` build types
2. **Backward Compatibility**: Maintain existing input/output interfaces
3. **Documentation**: Update this file with any new inputs/outputs
4. **Version Pinning**: Pin external action versions for reproducibility
