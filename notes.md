# Release & Deployment Notes

This document summarizes key practices and instructions for maintaining and developing this repository.

---

## Versioning & Tagging

- **Semantic Versions**  
    - Releases use semantic version tags (e.g., `v1.0.0`, `v2.1.3`, `v3.0.0-beta`) for clear rollback and audit trails.
    - These tags are never pruned.

- **Ephemeral Tags**  
    - **Branch-based:**  
        - Format: `<branch>-<full-sha>` (uses full 40-character commit SHA)
        - Created on every push to any branch.
        - Example: `dev-abc123def456...` (full SHA)
    - **PR-based:**  
        - Format: `pr-<number>`
        - Created/updated on pull request events.
        - Example: `pr-123`
    - Only the last 5 ephemeral tags are kept to keep the registry lean.
    - Also tagged as `latest` for convenience (points to most recent dev build)

- **Untagged Manifests**  
    - Orphaned image layers without tags are cleaned up automatically.
    - ACR Tasks purge runs daily to remove untagged manifests older than 2 days.
    - Works on Standard SKU (no Premium required).

- **Deployment Tags**  
    - Unique tags per deployment ensure deterministic rollouts.
    - "Stable" tags like `latest` are for convenience only and not used for rollbacks.

---

## GitHub Secrets Required

Add these secrets in your GitHub repository:

| Secret Name           | Description                                                                 |
|-----------------------|-----------------------------------------------------------------------------|
| `AZURE_CREDENTIALS`   | Service Principal JSON with ACR (AcrPush) and Web App (Website Contributor) |
| `ACR_NAME`            | Azure Container Registry name (without `.azurecr.io`)                       |
| `AZURE_WEBAPP_NAME`   | Azure Web App name                                                          |
| `AZURE_RESOURCE_GROUP`| Azure Resource Group                                                        |
| `ACR_USERNAME`/`ACR_PASSWORD` | Optional, for CLI deploy flow using registry credentials            |

---

## Local Development & Testing

1. **Set up Python environment:**
        ```sh
        python -m venv .venv
        source .venv/bin/activate
        pip install -r requirements.txt
        ```
2. **Run the app locally:**
        ```sh
        uvicorn backend.main:app --host 0.0.0.0 --port 8000
        # Visit http://localhost:8000
        ```
3. **Build & run container (optional):**
        ```sh
        docker build -t sample-app:dev .
        docker run --rm -p 8000:8000 -e DB_PATH=/data/app.db -v $(pwd)/data:/data sample-app:dev
        ```

---

## Azure Resource Setup

- Set environment variables (optional, defaults provided):
  - `RG` - Resource group name (default: `mysamplerg`)
  - `LOCATION` - Azure region (default: `centralindia`)
  - `ACR_NAME` - Container registry name, alphanumeric only (default: `mysampleacr`)
  - `PLAN_NAME` - App Service plan name (default: `mysampleplan`)
  - `WEBAPP_NAME` - Web app name, globally unique (default: `mysamplewebapp001`)

- Run infrastructure setup:
    ```bash
    # Use defaults
    bash infra/create-resources.sh
    
    # Or with custom names
    export WEBAPP_NAME="myapp$(date +%s)"
    export ACR_NAME="myacr$(date +%s)"
    bash infra/create-resources.sh
    ```

- **Important**: ACR names must be alphanumeric only (no hyphens or special characters)
- Push repo to GitHub and add required secrets.

---

## CI/CD Workflows

### 1. Development Build & Deploy (dev_mysamplewebapp001.yml)
- **Trigger:** Push to `dev` branch or manual
- **Actions:**
  - Builds Docker image
  - Tags: `dev-{full-sha}` and `latest`
  - Deploys the specific `dev-{full-sha}` tag to production
- **Note:** Deploys specific version for traceability, not `latest`

### 2. Release Build & Deploy (release-deploy.yml)
- **Trigger:** Git tag matching `v*.*.*` (e.g., v1.0.0) or manual
- **Actions:**
  - Builds Docker image
  - Tags: `v1.0.0`, `latest`, and `{commit-sha}`
  - Deploys the semantic version tag to production
- **Creating a release:**
    ```bash
    git tag v1.0.0
    git push origin v1.0.0
    ```
  Or via GitHub UI: Releases → Draft a new release → Create tag

### 3. Multi-Branch Build (build-push.yml)
- **Trigger:** Push to any branch or pull request
- **Actions:**
  - Builds and pushes images with ephemeral tags
  - Deploys to dev environment only when pushing to `dev` branch
  - PR builds are tagged as `pr-{number}`

---

## Checking Deployment & Logs

- Visit your web app URL.
- Tail logs:
        ```sh
        az webapp log tail -g <RG> -n <WEBAPP_NAME>
        ```

---

## Cleanup Workflows

### 1. ACR Tag Cleanup (acr-cleanup.yml)
- **Schedule:** Daily at 3 AM UTC
- **Purpose:** Removes old ephemeral tags, keeps semantic versions forever
- **What it does:**
  - Preserves ALL semantic version tags (v1.0.0, v2.1.3, etc.)
  - Keeps only last 5 ephemeral tags (dev-xxx, main-xxx, pr-xxx)
  - Deletes older ephemeral tags to reduce storage costs

### 2. ACR Untagged Images Cleanup (acr-purge-untagged.yml)
- **Schedule:** Daily at 2 AM UTC
- **Purpose:** Removes untagged manifests (orphaned image layers)
- **What it does:**
  - Deletes untagged manifests older than 2 days
  - Preserves ALL tagged images
  - Shows storage usage before/after cleanup
  - Works on Standard SKU (no Premium required)

### Manual Trigger Options

**GitHub UI:**
1. Go to [Actions](https://github.com/Infogain-GenAI/sample_app1/actions)
2. Select workflow ("ACR - Hybrid Cleanup" or "ACR - Purge Untagged Images")
3. Click "Run workflow", choose branch, and confirm

**GitHub CLI:**
```bash
# Tag cleanup
gh workflow run "ACR - Hybrid Cleanup" --ref dev

# Untagged images cleanup
gh workflow run "ACR - Purge Untagged Images" --ref dev
```

**Cleanup summaries** are available in workflow artifacts after each run.

---

## Troubleshooting: GitHub Workflow Push Errors

If you see:
```
! [remote rejected] dev -> dev (refusing to allow a Personal Access Token to create or update workflow .github/workflows/acr-cleanup.yml without workflow scope)
```
**Solution:**  
Update your Personal Access Token (PAT) to include the `workflow` scope.

### Steps:
1. Go to GitHub → Settings → Developer settings → Personal access tokens.
2. Edit or create a token with the `workflow` scope.
3. Update your credentials:
        ```sh
        git credential-manager-core erase https://github.com
        git push
        # Enter new token when prompted
        ```
4. Alternatively, use:
        - **GitHub CLI:** `gh auth login`
        - **SSH remote:**  
            ```sh
            git remote set-url origin git@github.com:Infogain-GenAI/sample_app1.git
            git push
            ```
        - **Temporarily move workflow files** if needed.

---

## Summary Table

| Tag Type           | Format                  | Created When              | Retention         | Example                      |
|--------------------|-------------------------|---------------------------|-------------------|------------------------------|
| Ephemeral (branch) | {branch}-{full-sha}     | Every branch push         | Last 5 kept       | dev-abc123def456... (full)   |
| Ephemeral (PR)     | pr-{number}             | PR open/update            | Last 5 kept       | pr-123                       |
| Semantic Version   | v{major}.{minor}.{patch}| Git release tag (manual)  | Never pruned      | v1.0.0, v2.1.3               |
| Latest             | latest                  | Dev branch push           | Overwritten       | latest (points to recent dev)|
| Untagged           | (no tag)                | Orphaned layers           | Deleted after 2d  | (manifests without tags)     |

---

For more details, see workflow files and scripts in the repository.
