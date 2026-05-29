# Docker Multi-Arch Build Workflow Diagram

## Overview

The `docker-build-multi-arch.yml` is a **wrapper workflow** that provides backward compatibility for Docker-only builds. It calls the unified `build-multi-arch.yml` workflow with `build-type: docker`.

## Workflow Architecture

```mermaid
flowchart TB
    subgraph consumer["Consumer Repository"]
        CALL["workflow_call<br/>docker-build-multi-arch.yml"]
    end

    subgraph wrapper["Wrapper Workflow"]
        DW["docker-build-multi-arch.yml"]
        DW_INPUTS["Inputs: dockerfile-path, context, etc."]
    end

    subgraph unified["Unified Core Workflow"]
        UW["build-multi-arch.yml<br/>build-type: docker"]
    end

    subgraph composite["Composite Actions"]
        CA1["aws-ecr-setup"]
        CA2["docker-buildx-setup"]
        CA3["github-auth-checkout"]
        CA4["gitversion-calculate"]
    end

    CALL --> DW
    DW --> DW_INPUTS
    DW_INPUTS -->|"build-type: docker"| UW
    UW --> CA1
    UW --> CA2
    UW --> CA3
    UW --> CA4

    style wrapper fill:#fff3e0
    style unified fill:#c8e6c9
    style composite fill:#e3f2fd
```

## Job Flow (via Unified Workflow)

When `build-type: docker` is passed to the unified workflow, the following jobs are executed:

```mermaid
flowchart TB
    subgraph trigger["Workflow Trigger"]
        WC[/"workflow_call"/]
    end

    subgraph inputs["Key Inputs"]
        direction LR
        I1["dockerfile-path (required)"]
        I2["ecr-repository"]
        I3["aws-account-id"]
        I4["aws-region"]
        I5["push"]
    end

    subgraph parallel_init["Parallel Initialization"]
        direction LR
        subgraph sanitization_job["sanitization"]
            S1["Sanitize branch name"]
            S2["Sanitize ECR repository name"]
            S3["Output: ref_name, ecr_repository"]
            S1 --> S2 --> S3
        end

        subgraph checks_job["checks"]
            C1["aws-ecr-setup action"]
            C2["Create ECR Repo if not exists"]
            C1 --> C2
        end

        subgraph version_job["version"]
            V1["github-auth-checkout action"]
            V2["gitversion-calculate action"]
            V3["Export PR Version"]
            V1 --> V2 --> V3
        end
    end

    subgraph docker_matrix["docker-build (matrix)"]
        direction TB
        subgraph amd64_build["amd64 Runner"]
            DA1["github-auth-checkout"]
            DA2["aws-ecr-setup"]
            DA3["docker-buildx-setup"]
            DA4["Build & Push amd64 image"]
            DA5["Upload amd64Tags artifact"]
            DA1 --> DA2 --> DA3 --> DA4 --> DA5
        end

        subgraph arm64_build["arm64 Runner"]
            DB1["github-auth-checkout"]
            DB2["aws-ecr-setup"]
            DB3["docker-buildx-setup"]
            DB4["Build & Push arm64 image"]
            DB5["Upload arm64Tags artifact"]
            DB1 --> DB2 --> DB3 --> DB4 --> DB5
        end
    end

    subgraph aggregate_job["aggregate-tags"]
        AT1["Download amd64Tags + arm64Tags"]
        AT2["Merge with jq"]
        AT3["Output: metaTags"]
        AT1 --> AT2 --> AT3
    end

    subgraph manifest_job["manifest"]
        M1["github-auth-checkout"]
        M2["aws-ecr-setup"]
        M3["docker-buildx-setup"]
        M4["Create Multi-Arch Manifest"]
        M5["Push Git Tag (main only)"]
        M6["Add PR Comment (PRs only)"]
        M1 --> M2 --> M3 --> M4 --> M5 --> M6
    end

    subgraph notify_job["notification_failures"]
        N1["Send Slack Notification"]
    end

    WC --> inputs
    inputs --> parallel_init

    sanitization_job --> docker_matrix
    checks_job --> docker_matrix
    version_job --> docker_matrix

    amd64_build --> aggregate_job
    arm64_build --> aggregate_job

    aggregate_job --> manifest_job

    sanitization_job -.->|on failure| notify_job
    checks_job -.->|on failure| notify_job
    version_job -.->|on failure| notify_job
    docker_matrix -.->|on failure| notify_job
    aggregate_job -.->|on failure| notify_job
    manifest_job -.->|on failure| notify_job

    style trigger fill:#e1f5fe
    style inputs fill:#fff3e0
    style parallel_init fill:#f3e5f5
    style docker_matrix fill:#fff8e1
    style aggregate_job fill:#fce4ec
    style manifest_job fill:#e0f2f1
    style notify_job fill:#ffebee
```

## Job Dependencies

```mermaid
graph LR
    subgraph "Job Dependency Graph"
        sanitization["sanitization"]
        checks["checks"]
        version["version"]
        docker["docker-build<br/>(amd64 + arm64)"]
        aggregate["aggregate-tags"]
        manifest["manifest"]
        notify["notification_failures"]

        sanitization --> docker
        checks --> docker
        version --> docker
        docker --> aggregate
        aggregate --> manifest

        sanitization -.-> notify
        checks -.-> notify
        version -.-> notify
        docker -.-> notify
        aggregate -.-> notify
        manifest -.-> notify
    end

    style sanitization fill:#e8f5e9
    style checks fill:#bbdefb
    style version fill:#c8e6c9
    style docker fill:#fff9c4
    style aggregate fill:#ffe0b2
    style manifest fill:#f8bbd9
    style notify fill:#ffcdd2
```

## Comparison: Docker vs Java Build

```mermaid
flowchart TB
    subgraph docker_workflow["docker-build-multi-arch.yml (build-type: docker)"]
        direction TB
        D1["sanitization"] --> D2["docker-build"]
        D3["checks"] --> D2
        D4["version"] --> D2
        D2 --> D5["aggregate-tags"]
        D5 --> D6["manifest"]
    end

    subgraph java_workflow["java-build-multi-arch.yml (build-type: java)"]
        direction TB
        J1["sanitization"] --> J3["docker-build"]
        J2["checks"] --> J3
        J4["version"] --> J5["gradle-build"]
        J5 --> J3
        J3 --> J6["aggregate-tags"]
        J6 --> J7["manifest"]
        J7 --> J8["sonarcloud-updates"]
    end

    style docker_workflow fill:#fff3e0
    style java_workflow fill:#e3f2fd
```

## Key Differences from Java Build

| Feature | docker-build-multi-arch | java-build-multi-arch |
| ------- | ----------------------- | --------------------- |
| Build Type | `docker` | `java` |
| Gradle Build | Skipped | Executed |
| Build Artifacts | Docker context only | JAR files from Gradle |
| SonarCloud Updates | Skipped | Executed (main branch) |
| Use Case | Generic Docker builds | Java applications |

## Inputs Reference

| Input | Type | Required | Default | Description |
| ----- | ---- | -------- | ------- | ----------- |
| `dockerfile-path` | string | Yes | `./Dockerfile` | Path to Dockerfile |
| `context` | string | No | `.` | Docker build context |
| `ecr-repository` | string | No | Repository name | ECR repository name |
| `aws-account-id` | string | No | `vars.AWS_CICD_ACCOUNT_ID` | AWS Account ID |
| `aws-region` | string | No | `vars.AWS_REGION` | AWS Region |
| `push` | string | No | `vars.DOCKER_BUILD_PUSH` | Push image after build |
| `provenance` | string | No | `vars.DOCKER_BUILD_PROVENANCE` | Enable SLSA provenance |
| `runsOnDefault` | string | No | `ubuntu-latest` | Default runner |
| `runsOnAmd64` | string | No | `vars.RUNS_ON_GHA_AMD64` | AMD64 runner |
| `runsOnArm64` | string | No | `vars.RUNS_ON_GHA_ARM64` | ARM64 runner |

## Secrets Reference

| Secret | Required | Description |
| ------ | -------- | ----------- |
| `PRIVATE_KEY` | Yes | GitHub App private key |
| `SLACK_BOT_TOKEN` | No | Slack bot token for notifications |
| `SONAR_TOKEN` | No | SonarCloud token (passed to Docker build) |

## Composite Actions Used

The workflow leverages these composite actions for DRY code:

```mermaid
flowchart LR
    subgraph "Composite Actions"
        CA1["aws-ecr-setup<br/>AWS OIDC + ECR Login"]
        CA2["docker-buildx-setup<br/>BuildX Configuration"]
        CA3["github-auth-checkout<br/>Auth + Checkout"]
        CA4["gitversion-calculate<br/>Version Calculation"]
    end

    subgraph "Jobs Using Actions"
        J1["checks"] --> CA1
        J2["version"] --> CA3
        J2 --> CA4
        J3["docker-build"] --> CA1
        J3 --> CA2
        J3 --> CA3
        J4["manifest"] --> CA1
        J4 --> CA2
        J4 --> CA3
    end

    style CA1 fill:#bbdefb
    style CA2 fill:#c8e6c9
    style CA3 fill:#fff9c4
    style CA4 fill:#f8bbd9
```

## Docker Caching Strategy

```mermaid
flowchart TB
    subgraph "Cache Sources (cache-from)"
        L1["Local Cache<br/>/tmp/buildx-cache-{arch}"]
        G1["GHA Cache<br/>scope: buildx-cache-{arch}"]
        G2["GHA Cache<br/>scope: buildx-cache-{branch}-{os}-{arch}"]
        R1["Registry Cache<br/>ECR:buildx-cache-{branch}-{os}-{arch}"]
    end

    subgraph "Cache Destinations (cache-to)"
        L2["Local Cache<br/>/tmp/buildx-cache-{arch}"]
        G3["GHA Cache<br/>scope: buildx-cache-{branch}-{os}-{arch}"]
        G4["GHA Cache<br/>scope: buildx-cache-{arch}"]
        R2["Registry Cache<br/>ECR:buildx-cache-{branch}-{os}-{arch}"]
        R3["Registry Cache<br/>ECR:buildx-cache-{branch}-{os}-{arch}-{sha}"]
    end

    L1 --> BUILD["Docker Build"]
    G1 --> BUILD
    G2 --> BUILD
    R1 --> BUILD

    BUILD --> L2
    BUILD --> G3
    BUILD --> G4
    BUILD --> R2
    BUILD --> R3

    note["All cache operations use<br/>ignore-error=true for resilience"]

    style BUILD fill:#fff9c4
    style note fill:#e8f5e9
```

## Usage Example

```yaml
name: CI

on:
  pull_request:
    types: [opened, synchronize, reopened]
  push:
    branches: ['**']
    tags-ignore: ['**']
  workflow_dispatch:

concurrency:
  group: ${{ github.event.repository.name }}-${{ github.event_name }}-${{ github.event.pull_request.number || github.ref_name }}-${{ github.sha }}
  cancel-in-progress: ${{ github.ref_name != github.event.repository.default_branch }}

jobs:
  build:
    uses: elioetibr/composite-actions/.github/workflows/docker-build-multi-arch.yml@main
    with:
      dockerfile-path: ./Dockerfile
      ecr-repository: ${{ github.event.repository.name }}
    secrets: inherit
```
