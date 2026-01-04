# Workflows & Scripts Reference

**Summary:**
This document provides a comprehensive overview of all CI/CD workflows and infrastructure scripts in the repository. It explains the purpose, triggers, and usage of each workflow YAML and script, helping you manage builds, deployments, ACR cleanup, and resource provisioning efficiently. Use this guide to understand automation, retention policies, and troubleshooting for your Azure-based application.

---

## GitHub Actions Workflows

## Workflow Summaries & Usage

### 1. `.github/workflows/cleanup-acr.yml`
- **Summary:** Cleans up old ephemeral tags in ACR, keeps all semantic version tags for rollback and audit.
- **Purpose:** Remove old ephemeral tags from ACR, keep semantic versions forever.
- **Trigger:** Scheduled daily at 1 AM UTC and manual dispatch.
- **Usage:**
    - Runs automatically on schedule
    - Manual: GitHub → Actions → Select workflow → Run workflow

### 2. `.github/workflows/dev_mysamplewebapp001.yml`
- **Summary:** Automates build and deployment for development branch changes.
- **Purpose:** Build and deploy app on every push to the `dev` branch.
- **Trigger:** Push to `dev` branch or manual dispatch.
- **Usage:**
    - Runs automatically on push to `dev`
    - Manual: GitHub → Actions → Select workflow → Run workflow

### 3. `.github/workflows/main_mysamplewebapp001.yml`
- **Summary:** Automates build and deployment for production branch changes.
- **Purpose:** Build and deploy app on every push to the `main` branch.
- **Trigger:** Push to `main` branch or manual dispatch.
- **Usage:**
    - Runs automatically on push to `main`
    - Manual: GitHub → Actions → Select workflow → Run workflow

### 4. `.github/workflows/promote-to-prod-import.yml`
- **Summary:** Promotes images from dev to prod ACR using Azure CLI import for efficient cross-registry transfer.
- **Purpose:** Promote image from dev ACR to prod ACR using Azure CLI import.
- **Trigger:** Tag push (release) or manual dispatch.
- **Usage:**
    - Runs automatically on tag push (e.g., `v1.0.0`)
    - Manual: GitHub → Actions → Select workflow → Run workflow

### 5. `.github/workflows/promote-to-prod-manual.yml`
- **Summary:** Allows manual promotion of dev images to prod ACR and deployment to prod web app.
- **Purpose:** Manually promote a dev image to prod ACR and deploy to prod web app.
- **Trigger:** Manual dispatch only.
- **Usage:**
    - Manual: GitHub → Actions → Select workflow → Run workflow

### 6. `.github/workflows/promote-to-prod.yml`
- **Summary:** Promotes images from dev to prod ACR using Docker pull/push for cross-registry transfer.
- **Purpose:** Promote image from dev ACR to prod ACR using Docker pull/push.
- **Trigger:** Tag push (release) or manual dispatch.
- **Usage:**
    - Runs automatically on tag push (e.g., `v1.0.0`)
    - Manual: GitHub → Actions → Select workflow → Run workflow

### 7. `.github/workflows/promote-to-release.yml`
- **Summary:** Retags dev images as release within the same ACR and deploys to production.
- **Purpose:** Retag dev image as release within the same ACR and deploy.
- **Trigger:** Tag push (release) or manual dispatch.
- **Usage:**
    - Runs automatically on tag push (e.g., `v1.0.0`)
    - Manual: GitHub → Actions → Select workflow → Run workflow

### 8. `.github/workflows/purge-acr-untagged.yml`
- **Summary:** Purges untagged manifests from ACR to free up storage and maintain registry hygiene.
- **Purpose:** Remove untagged manifests (orphaned image layers) from ACR to free up storage.
- **Trigger:** Scheduled daily at 2 AM UTC and manual dispatch.
- **Usage:**
    - Runs automatically on schedule
    - Manual: GitHub → Actions → Select workflow → Run workflow

### 9. `.github/workflows/release-deploy.yml`
- **Summary:** Automates build and deployment for production releases triggered by semantic version tags.
- **Purpose:** Build and deploy production releases on semantic version tag push (e.g., `v1.0.0`).
- **Trigger:** Tag push (release) or manual dispatch.
- **Usage:**
    - Runs automatically on tag push (e.g., `v1.0.0`)
    - Manual: GitHub → Actions → Select workflow → Run workflow

---

### 1. `.github/workflows/dev_mysamplewebapp001.yml`
- **Purpose:** Build and deploy the app on every push to the `dev` branch.
- **Summary:**
    - Builds Docker image
    - Tags as `dev-<sha>` and `latest`
    - Deploys to Azure Web App
- **How to Run:**
    - Triggered automatically on push to `dev`
    - Manual: Go to GitHub → Actions → Select workflow → Run workflow

### 2. `.github/workflows/release-deploy.yml`
- **Purpose:** Build and deploy production releases on semantic version tag push (e.g., `v1.0.0`).
- **Summary:**
    - Builds Docker image
    - Tags as `v*.*.*`, `latest`, and `<sha>`
    - Deploys semantic version tag to Azure Web App
- **How to Run:**
    - Triggered by pushing a tag: `git tag v1.0.0 && git push origin v1.0.0`
    - Manual: GitHub → Actions → Select workflow → Run workflow

### 3. `.github/workflows/cleanup-acr.yml`
- **Purpose:** Remove old ephemeral tags from Azure Container Registry, keep semantic versions forever.
- **Summary:**
    - Keeps all semantic version tags (`v*.*.*` or `V*.*.*`)
    - Retains only the most recent 5 ephemeral tags
    - Deletes older ephemeral tags
    - Prints summary of kept/deleted tags
- **How to Run:**
    - Scheduled daily at 1 AM UTC
    - Manual: GitHub → Actions → Select workflow → Run workflow

### 4. `.github/workflows/purge-acr-untagged.yml`
- **Purpose:** Remove untagged manifests (orphaned image layers) from ACR to free up storage.
- **Summary:**
    - Deletes untagged manifests older than 2 days
    - Preserves all tagged images
    - Shows storage usage before/after cleanup
- **How to Run:**
    - Scheduled daily at 2 AM UTC
    - Manual: GitHub → Actions → Select workflow → Run workflow

### 5. `misc/build-push.yml` (optional, in `misc/`)
- **Purpose:** Multi-branch build and PR tagging (not active by default).
- **Summary:**
    - Builds and pushes images for all branches and PRs
    - Tags as `pr-<number>` for pull requests
    - Deploys to dev environment on `dev` branch
- **How to Run:**
    - Move to `.github/workflows/` to activate
    - Triggered on branch push or PR

---

## Infrastructure Scripts (in `infra/`)

### 1. `infra/create-resources.sh`
- **Purpose:** Provision Azure resources (ACR, App Service Plan, Web App) for dev/prod.
- **How to Run:**
    ```bash
    bash infra/create-resources.sh
    # Or with custom names:
    export WEBAPP_NAME="myapp$(date +%s)"
    export ACR_NAME="myacr$(date +%s)"
    bash infra/create-resources.sh
    ```
- **Troubleshooting:**
    - Ensure Azure CLI is installed and logged in (`az login`)
    - Use alphanumeric names for ACR

### 2. `infra/cleanup_acr.sh`
- **Purpose:** Remove old ephemeral tags from ACR, keep semantic versions forever.
- **How to Run:**
    ```bash
    bash infra/cleanup_acr.sh <REGISTRY_NAME> <REPOSITORY_NAME> <KEEP_COUNT>
    # Example:
    bash infra/cleanup_acr.sh mysampleacr sample-app 5
    ```
- **Troubleshooting:**
    - Must have `AcrDelete` or `Contributor` role
    - Run `az login` before running
    - Script prints errors for failed deletions

### 3. `infra/purge_acr.sh`
- **Purpose:** Remove untagged manifests (orphaned layers) from ACR older than N days.
- **How to Run:**
    ```bash
    bash infra/purge_acr.sh <REGISTRY_NAME> <REPOSITORY_NAME> <AGO_DAYS> [--dry-run]
    # Example:
    bash infra/purge_acr.sh mysampleacr sample-app 2 --dry-run
    ```
- **Troubleshooting:**
    - Must have `AcrDelete` or `Contributor` role
    - Run `az login` before running
    - Only shows manifest-level summary (untagged images)

---

## Summary Table

| Workflow/Script                | Purpose                                      | How to Run                |
|-------------------------------|----------------------------------------------|--------------------------|
| dev_mysamplewebapp001.yml      | Dev build & deploy                           | Push to dev / Manual      |
| release-deploy.yml             | Release build & deploy                       | Tag push / Manual         |
| cleanup-acr.yml                | Tag cleanup (ephemeral/semantic)             | Scheduled / Manual        |
| purge-acr-untagged.yml         | Untagged manifest purge                      | Scheduled / Manual        |
| build-push.yml (misc/)         | Multi-branch/PR build (optional)             | Branch/PR push            |
| create-resources.sh            | Provision Azure resources                    | Bash script               |
| cleanup_acr.sh                 | Tag cleanup (ephemeral/semantic)             | Bash script               |
| purge_acr.sh                   | Untagged manifest purge                      | Bash script               |

---

## Troubleshooting Tips

- Always run `az login` before using scripts
- Ensure you have the correct Azure role (`AcrDelete` or `Contributor`)
- For workflow errors, check GitHub Actions logs and artifact summaries
- For script errors, review printed error messages for failed deletions
- Use `--dry-run` for purge scripts to preview actions

---
## Sample Commands

```bash
# Run tag cleanup script (keep last 5 ephemeral tags)
bash infra/cleanup_acr.sh mysampleacr sample-app 5

# Run untagged manifest purge (dry run)
bash infra/purge_acr.sh mysampleacr sample-app 2 --dry-run

# Provision Azure resources with defaults
bash infra/create-resources.sh
```

---

For more details, see each workflow YAML and script in the repository.
