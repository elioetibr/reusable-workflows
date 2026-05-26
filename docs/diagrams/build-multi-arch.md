# Unified Multi-Arch Build Pipeline Diagram

## Overview

The `build-multi-arch.yml` is the **core unified workflow** that powers all multi-architecture Docker builds. It uses a `build-type` input to conditionally enable Java-specific jobs while sharing all common build logic.

## Architecture

```mermaid
flowchart TB
    subgraph consumers["Consumer Repositories"]
        JAVA["Java Services"]
        DOCKER["Docker Services"]
    end

    subgraph wrappers["Wrapper Workflows"]
        JW["java-build-multi-arch.yml"]
        DW["docker-build-multi-arch.yml"]
    end

    subgraph unified["Unified Core Workflow"]
        UW["build-multi-arch.yml"]

        subgraph jobs["Jobs"]
            J1["sanitization"]
            J2["checks"]
            J3["version"]
            J4["gradle-build<br/>(Java only)"]
            J5["docker-build"]
            J6["aggregate-tags"]
            J7["manifest"]
            J8["sonarcloud-updates<br/>(Java only)"]
            J9["notification_failures"]
        end
    end

    subgraph composite["Composite Actions"]
        CA1["aws-ecr-setup"]
        CA2["docker-buildx-setup"]
        CA3["github-auth-checkout"]
        CA4["gitversion-calculate"]
    end

    JAVA --> JW
    DOCKER --> DW
    JW -->|"build-type: java"| UW
    DW -->|"build-type: docker"| UW
    UW --> composite

    style unified fill:#c8e6c9
    style wrappers fill:#e3f2fd
    style composite fill:#fff3e0
```

## Build Type Comparison

The `build-type` input determines which jobs are executed:

```mermaid
flowchart LR
    subgraph docker_mode["build-type: docker"]
        direction TB
        D1["sanitization"] --> D5["docker-build"]
        D2["checks"] --> D5
        D3["version"] --> D5
        D5 --> D6["aggregate-tags"]
        D6 --> D7["manifest"]
    end

    subgraph java_mode["build-type: java"]
        direction TB
        J1["sanitization"] --> J5["docker-build"]
        J2["checks"] --> J5
        J3["version"] --> J4["gradle-build"]
        J4 --> J5
        J5 --> J6["aggregate-tags"]
        J6 --> J7["manifest"]
        J7 --> J8["sonarcloud-updates"]
    end

    style docker_mode fill:#fff3e0
    style java_mode fill:#e3f2fd
```

| Job | build-type: docker | build-type: java |
| --- | ------------------ | ---------------- |
| sanitization | Executed | Executed |
| checks | Executed | Executed |
| version | Executed | Executed |
| gradle-build | **Skipped** | Executed |
| docker-build | Executed | Executed (depends on gradle-build) |
| aggregate-tags | Executed | Executed |
| manifest | Executed | Executed |
| sonarcloud-updates | **Skipped** | Executed (main branch only) |
| notification_failures | On failure | On failure |

## Complete Job Flow

```mermaid
flowchart TB
    subgraph trigger["Workflow Trigger"]
        WC[/"workflow_call"/]
        BT["build-type: docker | java"]
    end

    subgraph parallel_init["Parallel Initialization"]
        direction LR
        subgraph sanitization_job["sanitization"]
            S1["Sanitize branch name"]
            S2["Sanitize ECR repository"]
            S1 --> S2
        end

        subgraph checks_job["checks"]
            C1["aws-ecr-setup"]
            C2["Create ECR Repo"]
            C1 --> C2
        end

        subgraph version_job["version"]
            V1["github-auth-checkout"]
            V2["gitversion-calculate"]
            V3["Export PR Version"]
            V1 --> V2 --> V3
        end
    end

    subgraph gradle_job["gradle-build (Java only)"]
        G1["github-auth-checkout"]
        G2["aws-ecr-setup"]
        G3["Setup JDK"]
        G4["Cache Gradle"]
        G5["./gradlew build"]
        G6["Upload build-libs"]
        G1 --> G2 --> G3 --> G4 --> G5 --> G6
    end

    subgraph docker_matrix["docker-build (matrix)"]
        direction TB
        subgraph amd64["amd64 Runner"]
            DA1["github-auth-checkout"]
            DA2["aws-ecr-setup"]
            DA3["Download build-libs (Java)"]
            DA4["docker-buildx-setup"]
            DA5["Build & Push"]
            DA6["Upload tags"]
            DA1 --> DA2 --> DA3 --> DA4 --> DA5 --> DA6
        end

        subgraph arm64["arm64 Runner"]
            DB1["github-auth-checkout"]
            DB2["aws-ecr-setup"]
            DB3["Download build-libs (Java)"]
            DB4["docker-buildx-setup"]
            DB5["Build & Push"]
            DB6["Upload tags"]
            DB1 --> DB2 --> DB3 --> DB4 --> DB5 --> DB6
        end
    end

    subgraph aggregate_job["aggregate-tags"]
        AT1["Download all tags"]
        AT2["Merge with jq"]
        AT1 --> AT2
    end

    subgraph manifest_job["manifest"]
        M1["github-auth-checkout"]
        M2["aws-ecr-setup"]
        M3["docker-buildx-setup"]
        M4["Create manifest"]
        M5["Push git tag"]
        M6["PR comment"]
        M1 --> M2 --> M3 --> M4 --> M5 --> M6
    end

    subgraph sonar_job["sonarcloud-updates (Java only, main)"]
        SC1["github-auth-checkout"]
        SC2["aws-ecr-setup"]
        SC3["Setup JDK"]
        SC4["./gradlew sonar"]
        SC1 --> SC2 --> SC3 --> SC4
    end

    subgraph notify_job["notification_failures"]
        N1["Slack notification"]
    end

    WC --> BT
    BT --> parallel_init

    sanitization_job --> docker_matrix
    checks_job --> docker_matrix
    version_job --> gradle_job
    gradle_job --> docker_matrix

    amd64 --> aggregate_job
    arm64 --> aggregate_job

    aggregate_job --> manifest_job
    manifest_job --> sonar_job

    parallel_init -.->|on failure| notify_job
    gradle_job -.->|on failure| notify_job
    docker_matrix -.->|on failure| notify_job
    manifest_job -.->|on failure| notify_job

    style trigger fill:#e1f5fe
    style parallel_init fill:#f3e5f5
    style gradle_job fill:#e8f5e9
    style docker_matrix fill:#fff8e1
    style aggregate_job fill:#fce4ec
    style manifest_job fill:#e0f2f1
    style sonar_job fill:#c8e6c9
    style notify_job fill:#ffebee
```

## Composite Actions Integration

The unified workflow leverages four composite actions for DRY code:

```mermaid
flowchart TB
    subgraph actions["Composite Actions"]
        CA1["aws-ecr-setup<br/>AWS OIDC + ECR Login"]
        CA2["docker-buildx-setup<br/>BuildX with ECR BuildKit"]
        CA3["github-auth-checkout<br/>App Token + Checkout"]
        CA4["gitversion-calculate<br/>Cache + Setup + Execute"]
    end

    subgraph usage["Usage by Job"]
        J1["checks"] --> CA1
        J2["version"] --> CA3
        J2 --> CA4
        J3["gradle-build"] --> CA1
        J3 --> CA3
        J4["docker-build"] --> CA1
        J4 --> CA2
        J4 --> CA3
        J5["manifest"] --> CA1
        J5 --> CA2
        J5 --> CA3
        J6["sonarcloud-updates"] --> CA1
        J6 --> CA3
    end

    style CA1 fill:#bbdefb
    style CA2 fill:#c8e6c9
    style CA3 fill:#fff9c4
    style CA4 fill:#f8bbd9
```

## Key Inputs

| Input | Type | Required | Description |
| ----- | ---- | -------- | ----------- |
| `build-type` | string | **Yes** | `docker` or `java` |
| `aws-account-id` | string | No | AWS Account ID |
| `aws-region` | string | No | AWS Region |
| `ecr-repository` | string | No | ECR repository name |
| `dockerfile-path` | string | No | Path to Dockerfile |
| `context` | string | No | Docker build context |
| `jdk-version` | number | Java only | JDK version |
| `jdk-distribution` | string | No | JDK distribution |
| `uses-sonar` | boolean | No | Enable SonarCloud |
| `push` | string | No | Push image after build |

## Outputs

| Output | Description |
| ------ | ----------- |
| `version` | Major.Minor.Patch version |
| `semVer` | Full semantic version |
| `shortSha` | Short commit SHA |

## Conditional Job Logic

### gradle-build Job

```yaml
gradle-build:
  if: ${{ inputs.build-type == 'java' && success() && !contains(...) }}
```

Only runs when `build-type: java`.

### docker-build Job

```yaml
docker-build:
  needs: [sanitization, checks, version, gradle-build]
  if: |
    always() &&
    needs.sanitization.result == 'success' &&
    needs.checks.result == 'success' &&
    needs.version.result == 'success' &&
    (inputs.build-type == 'docker' || needs.gradle-build.result == 'success')
```

Handles both build types by checking if gradle-build was needed.

### sonarcloud-updates Job

```yaml
sonarcloud-updates:
  if: |
    inputs.build-type == 'java' &&
    success() &&
    github.ref_name == github.event.repository.default_branch
```

Only runs for Java builds on the main branch.

## Docker Caching Strategy

```mermaid
flowchart TB
    subgraph sources["Cache Sources"]
        L1["Local: /tmp/buildx-cache-{arch}"]
        G1["GHA: buildx-cache-{arch}"]
        G2["GHA: buildx-cache-{branch}-{os}-{arch}"]
        R1["Registry: ECR buildx-cache"]
    end

    BUILD["Docker Build"]

    subgraph destinations["Cache Destinations"]
        L2["Local cache"]
        G3["GHA cache (branch-scoped)"]
        G4["GHA cache (arch-scoped)"]
        R2["Registry cache"]
        R3["Registry cache (SHA-scoped)"]
    end

    sources --> BUILD --> destinations

    style BUILD fill:#fff9c4
```

## Artifact Flow

```mermaid
flowchart LR
    subgraph "Artifact Pipeline"
        gradle["gradle-build<br/>(Java only)"]
        amd64["docker-build<br/>(amd64)"]
        arm64["docker-build<br/>(arm64)"]
        aggregate["aggregate-tags"]
        manifest["manifest"]

        gradle -->|"build-libs"| amd64
        gradle -->|"build-libs"| arm64

        amd64 -->|"meta-tags-amd64Tags"| aggregate
        arm64 -->|"meta-tags-arm64Tags"| aggregate

        aggregate -->|"metaTags"| manifest
    end

    style gradle fill:#c8e6c9
    style amd64 fill:#bbdefb
    style arm64 fill:#b3e5fc
    style aggregate fill:#ffe0b2
    style manifest fill:#f8bbd9
```

## Benefits of Unified Architecture

1. **Single Source of Truth**: All build logic in one workflow
2. **DRY Principle**: No duplicated code between Java and Docker builds
3. **Consistent Behavior**: Same caching, tagging, and manifest creation
4. **Easy Maintenance**: Fix once, apply everywhere
5. **Backward Compatibility**: Wrapper workflows maintain original APIs
6. **Extensibility**: Easy to add new build types (Node.js, Python, etc.)

## Adding New Build Types

To add a new build type (e.g., `nodejs`):

1. Add new conditional job(s) in `build-multi-arch.yml`
2. Create wrapper workflow `nodejs-build-multi-arch.yml`
3. Pass `build-type: nodejs` to the unified workflow

```yaml
# nodejs-build-multi-arch.yml (example)
jobs:
  build:
    uses: ./.github/workflows/build-multi-arch.yml
    with:
      build-type: nodejs
      node-version: 20
    secrets: inherit
```
