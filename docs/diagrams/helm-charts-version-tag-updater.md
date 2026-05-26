# Helm Charts Version Tag Updater Workflow

## Workflow Overview

This workflow automates the process of updating Docker image tags in Helm chart repositories. It validates inputs, checks that images exist in ECR, updates values.yaml files, creates PRs, and auto-approves safe changes.

**Uses Composite Action:** `github-auth-checkout` for GitHub authentication and repository checkout.

```mermaid
flowchart TB
    subgraph trigger["Workflow Trigger"]
        WC[/"workflow_call"/]
    end

    subgraph inputs["Required Inputs"]
        direction TB
        I1["base_branch<br/>(PR target branch)"]
        I2["service<br/>(e.g., auth-service)"]
        I3["cluster<br/>(dev01 or prod01)"]
        I4["environment<br/>(namespace)"]
        I5["tag<br/>(Docker image tag)"]
        I6["jira_ticket<br/>(optional)"]
    end

    subgraph composite["Composite Action"]
        CA["github-auth-checkout<br/>Bot config + Token + Checkout"]
    end

    subgraph validate_job["validate-and-update"]
        direction TB

        subgraph validation["Input Validation"]
            VA1["Validate service name"]
            VA2["Validate cluster"]
            VA3["Validate environment for cluster"]
            VA1 --> VA2 --> VA3
        end

        subgraph image_validation["Image Validation"]
            IV1["Extract image info from values.yaml"]
            IV2["Configure AWS credentials"]
            IV3["Check image exists in ECR"]
            IV1 --> IV2 --> IV3
        end

        subgraph update["Update Files"]
            UP1["Create feature branch"]
            UP2["Update Chart.yaml appVersion<br/>(prod only)"]
            UP3["Update values.yaml image.tag"]
            UP4["Commit changes"]
            UP5["Push branch"]
            UP1 --> UP2 --> UP3 --> UP4 --> UP5
        end

        subgraph pr["Pull Request"]
            PR1["Create/Update PR"]
            PR2["Add labels"]
            PR3["Auto-approve<br/>(safe changes only)"]
            PR1 --> PR2 --> PR3
        end

        validation --> image_validation
        image_validation --> update
        update --> pr
    end

    subgraph outputs["Outputs"]
        O1["pr_number"]
        O2["pr_url"]
        O3["updated_count"]
    end

    WC --> inputs
    inputs --> composite
    composite --> validate_job
    pr --> outputs

    style trigger fill:#e1f5fe
    style inputs fill:#fff3e0
    style composite fill:#fff9c4
    style validate_job fill:#e8f5e9
    style outputs fill:#e8eaf6
```

## Composite Action Integration

This workflow uses the `github-auth-checkout` composite action to consolidate:

1. **GitHub Bot Configuration** - Sets up bot identity for commits
2. **GitHub App Token Generation** - Creates authentication token
3. **Repository Checkout** - Clones the repository with proper auth

```mermaid
flowchart LR
    subgraph before["Before Refactoring"]
        B1["GitHub Bot Config"]
        B2["Generate App Token"]
        B3["Checkout"]
        B1 --> B2 --> B3
    end

    subgraph after["After Refactoring"]
        A1["github-auth-checkout<br/>(composite action)"]
    end

    before -.->|"Consolidated into"| after

    style before fill:#ffcdd2
    style after fill:#c8e6c9
```

## Validation Flow

```mermaid
flowchart TB
    subgraph service_validation["Service Validation"]
        SV1["Input: service name"]
        SV2{{"Is valid service?"}}
        SV3["Continue"]
        SV4["Exit with error"]

        SV1 --> SV2
        SV2 -->|Yes| SV3
        SV2 -->|No| SV4
    end

    subgraph cluster_validation["Cluster Validation"]
        CV1["Input: cluster"]
        CV2{{"dev01 or prod01?"}}
        CV3["Continue"]
        CV4["Exit with error"]

        CV1 --> CV2
        CV2 -->|Yes| CV3
        CV2 -->|No| CV4
    end

    subgraph env_validation["Environment Validation"]
        EV1["Input: environment"]
        EV2{{"Valid for cluster?"}}
        EV3["Continue to update"]
        EV4["Exit with error"]

        EV1 --> EV2
        EV2 -->|Yes| EV3
        EV2 -->|No| EV4
    end

    service_validation --> cluster_validation
    cluster_validation --> env_validation

    style service_validation fill:#e3f2fd
    style cluster_validation fill:#fff3e0
    style env_validation fill:#e8f5e9
```

## Valid Environments by Cluster

```mermaid
flowchart TB
    subgraph clusters["Cluster Configuration"]
        subgraph dev01["dev01 Cluster"]
            D1["vf-dev2"]
            D2["vf-dev3"]
            D3["vf-dev4"]
            D4["vf-dev5"]
            D5["vf-test2"]
            D6["vf-test3"]
            D7["vf-test4"]
            D8["all"]
        end

        subgraph prod01["prod01 Cluster"]
            P1["viafoura"]
        end
    end

    style dev01 fill:#e8f5e9
    style prod01 fill:#ffebee
```

## File Update Strategy

```mermaid
flowchart TB
    subgraph strategy["Update Strategy"]
        direction TB

        subgraph single_env["Single Environment"]
            SE1["Find values.yaml in<br/>apps/{service}/envs/.../namespaces/{env}/"]
            SE2["Update image.tag field"]
        end

        subgraph all_env["Environment = 'all'"]
            AE1["Find all values.yaml in<br/>apps/{service}/envs/**/namespaces/*/"]
            AE2["Update image.tag in all files"]
        end

        subgraph prod_only["Production Only"]
            PO1["Update Chart.yaml appVersion"]
            PO2["Used for Helm releases"]
        end
    end

    ENV{{"environment == 'all'?"}}
    PROD{{"cluster == 'prod01'?"}}

    ENV -->|Yes| all_env
    ENV -->|No| single_env

    single_env --> PROD
    all_env --> PROD

    PROD -->|Yes| prod_only

    style single_env fill:#e3f2fd
    style all_env fill:#fff3e0
    style prod_only fill:#ffebee
```

## Auto-Approval Logic

```mermaid
flowchart TB
    subgraph approval["Auto-Approval Decision"]
        A1["Analyze git diff"]
        A2{{"Only image.tag or<br/>appVersion changes?"}}
        A3["Mark safe_for_auto_approve=true"]
        A4["Mark safe_for_auto_approve=false"]
        A5["Auto-approve PR"]
        A6["Require manual review"]

        A1 --> A2
        A2 -->|Yes| A3
        A2 -->|No| A4
        A3 --> A5
        A4 --> A6
    end

    style A3 fill:#c8e6c9
    style A4 fill:#ffcdd2
    style A5 fill:#a5d6a7
    style A6 fill:#ef9a9a
```

## Branch Naming Convention

```mermaid
flowchart LR
    subgraph naming["Branch Name Pattern"]
        direction TB

        subgraph with_jira["With Jira Ticket"]
            WJ["auto-update/{JIRA}/{service}-{cluster}-{env}-{tag}"]
            WJE["Example:<br/>auto-update/COM-123/auth-service-dev01-vf-dev2-1.2.3"]
        end

        subgraph without_jira["Without Jira Ticket"]
            WOJ["auto-update/{service}-{cluster}-{env}-{tag}"]
            WOJE["Example:<br/>auto-update/auth-service-dev01-vf-dev2-1.2.3"]
        end
    end

    style with_jira fill:#e3f2fd
    style without_jira fill:#fff3e0
```

## Inputs Reference

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `base_branch` | string | Yes | Target branch for the PR |
| `service` | string | Yes | Service name (must be valid) |
| `cluster` | string | Yes | Cluster name (`dev01` or `prod01`) |
| `environment` | string | Yes | Namespace/environment |
| `tag` | string | Yes | Docker image tag to deploy |
| `jira_ticket` | string | No | Jira ticket for tracking |

## Valid Services

```
auth-service, auth0-oidc-demo, cassandra, comment-import,
common-external-services, console, console-moderation,
console-opensearch, data-burrito, email, flume, gdpr-mediation,
heimdall, ingestor, java-vertx-template, legacy-gdpr-connector,
livechat, livecomments, livequestions, livereviews, livestories,
moderation-orchestrator, polls, realtime-event-feed, spam-moderation,
tyrion, ucs-moderation, user-import, user-interaction,
user-notification, viafoura-front, webhooks, webhooks-client
```

## Outputs Reference

| Output | Description |
|--------|-------------|
| `pr_number` | The PR number created |
| `pr_url` | The PR URL created |
| `updated_count` | Number of files updated |

## Usage Example

```yaml
name: Deploy to Dev

on:
  workflow_dispatch:
    inputs:
      tag:
        description: 'Docker image tag'
        required: true
      environment:
        description: 'Environment'
        required: true
        type: choice
        options:
          - vf-dev2
          - vf-dev3
          - vf-dev4
          - vf-dev5
          - all
      jira_ticket:
        description: 'Jira ticket (optional)'
        required: false

jobs:
  update-version:
    uses: elioetibr/composite-actions/.github/workflows/apps-of-apps-application-version-update.yml@main
    with:
      base_branch: main
      service: my-service
      cluster: dev01
      environment: ${{ github.event.inputs.environment }}
      tag: ${{ github.event.inputs.tag }}
      jira_ticket: ${{ github.event.inputs.jira_ticket }}
    secrets:
      PRIVATE_KEY: ${{ secrets.PRIVATE_KEY }}
```

## Error Handling

The workflow provides detailed error summaries in GitHub Actions:

```mermaid
flowchart TB
    subgraph errors["Error Scenarios"]
        E1["Invalid service name"]
        E2["Invalid cluster"]
        E3["Invalid environment for cluster"]
        E4["Image not found in ECR"]
        E5["No matching values.yaml files"]
        E6["Git push failed"]
        E7["PR creation failed"]
    end

    subgraph summary["GitHub Step Summary"]
        S1["Failure Analysis"]
        S2["Input Parameters"]
        S3["Troubleshooting Steps"]
        S4["Workflow Run Link"]
    end

    errors --> summary

    style errors fill:#ffebee
    style summary fill:#e8f5e9
```
