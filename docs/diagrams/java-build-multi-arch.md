# Java Multi-Arch Build Workflow Diagram

## Overview

The `java-build-multi-arch.yml` is a **wrapper workflow** that provides a complete CI/CD pipeline for Java applications. It calls the unified `build-multi-arch.yml` workflow with `build-type: java`.

## Workflow Architecture

```mermaid
flowchart TB
    subgraph consumer["Consumer Repository"]
        CALL["workflow_call<br/>java-build-multi-arch.yml"]
    end

    subgraph wrapper["Wrapper Workflow"]
        JW["java-build-multi-arch.yml"]
        JW_INPUTS["Inputs: jdk-version, uses-sonar, etc."]
    end

    subgraph unified["Unified Core Workflow"]
        UW["build-multi-arch.yml<br/>build-type: java"]
    end

    subgraph composite["Composite Actions"]
        CA1["aws-ecr-setup"]
        CA2["docker-buildx-setup"]
        CA3["github-auth-checkout"]
        CA4["gitversion-calculate"]
    end

    CALL --> JW
    JW --> JW_INPUTS
    JW_INPUTS -->|"build-type: java"| UW
    UW --> CA1
    UW --> CA2
    UW --> CA3
    UW --> CA4

    style wrapper fill:#e3f2fd
    style unified fill:#c8e6c9
    style composite fill:#fff3e0
```

## Job Flow (via Unified Workflow)

When `build-type: java` is passed to the unified workflow, all jobs are executed including Java-specific ones:

```mermaid
flowchart TB
    subgraph trigger["Workflow Trigger"]
        WC[/"workflow_call"/]
    end

    subgraph inputs["Key Inputs"]
        direction LR
        I1["jdk-version (required)"]
        I2["ecr-repository"]
        I3["uses-sonar"]
        I4["uses-editorconfig"]
        I5["jdk-distribution"]
    end

    subgraph parallel_start["Parallel Initialization Jobs"]
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

    subgraph gradle_job["gradle-build (Java only)"]
        G1["github-auth-checkout"]
        G2["aws-ecr-setup"]
        G3["Setup JDK"]
        G4["Cache Gradle packages"]
        G5["Run ./gradlew build"]
        G6["Optional: SonarCloud analysis"]
        G7["Upload build-libs artifact"]
        G1 --> G2 --> G3 --> G4 --> G5 --> G6 --> G7
    end

    subgraph docker_matrix["docker-build (matrix)"]
        direction TB
        subgraph amd64_build["amd64 Runner"]
            DA1["github-auth-checkout"]
            DA2["aws-ecr-setup"]
            DA3["Download build-libs"]
            DA4["docker-buildx-setup"]
            DA5["Build & Push amd64 image"]
            DA6["Upload amd64Tags artifact"]
            DA1 --> DA2 --> DA3 --> DA4 --> DA5 --> DA6
        end

        subgraph arm64_build["arm64 Runner"]
            DB1["github-auth-checkout"]
            DB2["aws-ecr-setup"]
            DB3["Download build-libs"]
            DB4["docker-buildx-setup"]
            DB5["Build & Push arm64 image"]
            DB6["Upload arm64Tags artifact"]
            DB1 --> DB2 --> DB3 --> DB4 --> DB5 --> DB6
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

    subgraph sonar_job["sonarcloud-updates (Java only, main branch)"]
        SC1["github-auth-checkout"]
        SC2["aws-ecr-setup"]
        SC3["Setup JDK"]
        SC4["Run ./gradlew build sonar"]
        SC1 --> SC2 --> SC3 --> SC4
    end

    subgraph notify_job["notification_failures"]
        N1["Send Slack Notification"]
    end

    subgraph outputs["Outputs"]
        O1["version"]
        O2["semVer"]
        O3["shortSha"]
    end

    WC --> inputs
    inputs --> parallel_start

    sanitization_job --> docker_matrix
    checks_job --> docker_matrix
    version_job --> gradle_job
    gradle_job --> docker_matrix

    amd64_build --> aggregate_job
    arm64_build --> aggregate_job

    aggregate_job --> manifest_job
    manifest_job --> sonar_job
    manifest_job --> outputs

    sanitization_job -.->|on failure| notify_job
    checks_job -.->|on failure| notify_job
    version_job -.->|on failure| notify_job
    gradle_job -.->|on failure| notify_job
    docker_matrix -.->|on failure| notify_job
    aggregate_job -.->|on failure| notify_job
    manifest_job -.->|on failure| notify_job

    style trigger fill:#e1f5fe
    style inputs fill:#fff3e0
    style parallel_start fill:#f3e5f5
    style gradle_job fill:#e8f5e9
    style docker_matrix fill:#fff8e1
    style aggregate_job fill:#fce4ec
    style manifest_job fill:#e0f2f1
    style sonar_job fill:#c8e6c9
    style notify_job fill:#ffebee
    style outputs fill:#e8eaf6
```

## Job Dependencies

```mermaid
graph LR
    subgraph "Job Dependency Graph"
        sanitization["sanitization"]
        checks["checks"]
        version["version"]
        gradle["gradle-build"]
        docker["docker-build<br/>(amd64 + arm64)"]
        aggregate["aggregate-tags"]
        manifest["manifest"]
        sonar["sonarcloud-updates"]
        notify["notification_failures"]

        version --> gradle
        sanitization --> docker
        checks --> docker
        gradle --> docker
        version --> docker
        docker --> aggregate
        aggregate --> manifest
        manifest --> sonar

        sanitization -.-> notify
        checks -.-> notify
        version -.-> notify
        gradle -.-> notify
        docker -.-> notify
        aggregate -.-> notify
        manifest -.-> notify
    end

    style sanitization fill:#e8f5e9
    style checks fill:#bbdefb
    style version fill:#c8e6c9
    style gradle fill:#dcedc8
    style docker fill:#fff9c4
    style aggregate fill:#ffe0b2
    style manifest fill:#f8bbd9
    style sonar fill:#b2dfdb
    style notify fill:#ffcdd2
```

## Artifact Flow

```mermaid
flowchart LR
    subgraph "Artifact Pipeline"
        gradle["gradle-build"]
        amd64["docker-build<br/>(amd64)"]
        arm64["docker-build<br/>(arm64)"]
        aggregate["aggregate-tags"]
        manifest["manifest"]

        gradle -->|"build-libs<br/>(JAR files)"| amd64
        gradle -->|"build-libs<br/>(JAR files)"| arm64

        amd64 -->|"meta-tags-amd64Tags<br/>(JSON)"| aggregate
        arm64 -->|"meta-tags-arm64Tags<br/>(JSON)"| aggregate

        aggregate -->|"metaTags<br/>(merged JSON)"| manifest
    end

    style gradle fill:#c8e6c9
    style amd64 fill:#bbdefb
    style arm64 fill:#b3e5fc
    style aggregate fill:#ffe0b2
    style manifest fill:#f8bbd9
```

## Comparison: Java vs Docker Build

```mermaid
flowchart TB
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

    subgraph docker_workflow["docker-build-multi-arch.yml (build-type: docker)"]
        direction TB
        D1["sanitization"] --> D2["docker-build"]
        D3["checks"] --> D2
        D4["version"] --> D2
        D2 --> D5["aggregate-tags"]
        D5 --> D6["manifest"]
    end

    style java_workflow fill:#e3f2fd
    style docker_workflow fill:#fff3e0
```

## Key Differences from Docker Build

| Feature | java-build-multi-arch | docker-build-multi-arch |
| ------- | --------------------- | ----------------------- |
| Build Type | `java` | `docker` |
| Gradle Build | Executed | Skipped |
| Build Artifacts | JAR files from Gradle | Docker context only |
| SonarCloud Updates | Executed (main branch) | Skipped |
| Use Case | Java applications | Generic Docker builds |
| JDK Setup | Required input | Not applicable |

## Inputs Reference

| Input | Type | Required | Default | Description |
| ----- | ---- | -------- | ------- | ----------- |
| `jdk-version` | number | **Yes** | - | JDK version (8, 11, 17, 21) |
| `jdk-distribution` | string | No | `corretto` | JDK distribution |
| `context` | string | No | `.` | Docker build context path |
| `file` | string | No | `./Dockerfile` | Path to Dockerfile |
| `ecr-repository` | string | No | Repository name | ECR repository name |
| `uses-sonar` | boolean | No | PR-based | Enable SonarCloud analysis |
| `uses-editorconfig` | boolean | No | `false` | Enable editorconfig validation |
| `upload-artifacts` | boolean | No | `true` | Upload build artifacts |
| `runsOnDefault` | string | No | `ubuntu-latest` | Runner for general jobs |
| `runsOnAmd64` | string | No | `vars.RUNS_ON_GHA_AMD64` | Runner for AMD64 builds |
| `runsOnArm64` | string | No | `vars.RUNS_ON_GHA_ARM64` | Runner for ARM64 builds |

## Secrets Reference

| Secret | Required | Description |
| ------ | -------- | ----------- |
| `PRIVATE_KEY` | Yes | GitHub App private key |
| `SONAR_TOKEN` | Yes | SonarCloud token |
| `SLACK_BOT_TOKEN` | Yes | Slack bot token for notifications |

## Outputs Reference

| Output | Description |
| ------ | ----------- |
| `version` | Version calculated by GitVersion (e.g., `1.2.3`) |
| `semVer` | Full semantic version (e.g., `1.2.3-alpha.1`) |
| `shortSha` | Short commit SHA (e.g., `abc1234`) |

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

    style BUILD fill:#fff9c4
```

## Version Tagging Strategy

```mermaid
flowchart TB
    subgraph "Tag Generation"
        GV["GitVersion<br/>calculates semVer"]

        subgraph "Per Architecture Tags"
            AMD["amd64-{semVer}"]
            ARM["arm64-{semVer}"]
        end

        subgraph "PR Tags (conditional)"
            PRAMD["amd64-PR-{number}-{attempt}-{sha}"]
            PRARM["arm64-PR-{number}-{attempt}-{sha}"]
        end

        subgraph "Multi-Arch Manifest Tags"
            SEM["{semVer}"]
            LATEST["latest<br/>(main branch only)"]
            PRTAG["PR-{number}-{attempt}-{sha}<br/>(PRs only)"]
        end
    end

    GV --> AMD
    GV --> ARM
    GV --> PRAMD
    GV --> PRARM

    AMD --> SEM
    ARM --> SEM
    AMD --> LATEST
    ARM --> LATEST
    PRAMD --> PRTAG
    PRARM --> PRTAG

    style GV fill:#c8e6c9
    style SEM fill:#fff9c4
    style LATEST fill:#bbdefb
    style PRTAG fill:#f8bbd9
```

## Runner Architecture

```mermaid
flowchart TB
    subgraph "Runner Assignment"
        DEFAULT["runsOnDefault<br/>(ubuntu-latest)"]
        AMD64["runsOnAmd64<br/>(gha-linux-amd64)"]
        ARM64["runsOnArm64<br/>(gha-linux-arm64)"]
    end

    subgraph "Jobs by Runner"
        subgraph default_jobs["Default Runner Jobs"]
            checks["checks"]
            version["version"]
            gradle["gradle-build"]
            aggregate["aggregate-tags"]
            manifest["manifest"]
            sonar["sonarcloud-updates"]
            notify["notification_failures"]
        end

        subgraph amd64_jobs["AMD64 Runner Jobs"]
            docker_amd["docker-build (amd64)"]
        end

        subgraph arm64_jobs["ARM64 Runner Jobs"]
            docker_arm["docker-build (arm64)"]
        end
    end

    DEFAULT --> default_jobs
    AMD64 --> amd64_jobs
    ARM64 --> arm64_jobs

    style DEFAULT fill:#e1f5fe
    style AMD64 fill:#fff3e0
    style ARM64 fill:#f3e5f5
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
    uses: elioetibr/composite-actions/.github/workflows/java-build-multi-arch.yml@main
    with:
      jdk-version: 21
      ecr-repository: ${{ github.event.repository.name }}
      uses-sonar: true
    secrets: inherit
```
