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

### How to Get AZURE_CREDENTIALS (Service Principal)

**Prerequisites:** You need Azure AD permissions to create service principals. If you don't have permissions, ask your Azure administrator.

**Step 1: Get Your Subscription ID**
```bash
az account show --query id -o tsv
```

**Step 2: Create Service Principal (Choose one option)**

**Option A: Scoped to Resource Group (Recommended - Least Privilege)**
```bash
az ad sp create-for-rbac \
  --name "github-actions-sample-app" \
  --role Contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/mysamplerg \
  --json-auth
```

**Option B: Scoped to Subscription (More Permissions)**
```bash
# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Create service principal
az ad sp create-for-rbac \
  --name "github-actions-sample-app" \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID \
  --json-auth
```

**Note:** The `--sdk-auth` flag is deprecated. Use `--json-auth` for newer Azure CLI versions.

**Step 3: Copy the JSON Output**

The command will output JSON like this:
```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

**Step 4: Add to GitHub Secrets**
1. Go to your GitHub repository: `https://github.com/Infogain-GenAI/sample_app1`
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `AZURE_CREDENTIALS`
5. Value: Paste the **entire JSON output** from Step 3 (including curly braces)
6. Click **Add secret**

**Step 5: Verify**
Test the cleanup workflows manually:
1. Go to **Actions** tab in GitHub
2. Select **ACR - Hybrid Cleanup** or **ACR - Purge Untagged Images**
3. Click **Run workflow** → **Run workflow**
4. Verify it completes without authentication errors

**Troubleshooting:**
- **"Insufficient privileges"**: Contact your Azure administrator to create the service principal
- **"Login failed"**: Ensure the entire JSON is copied correctly (no extra spaces/newlines)
- **"Subscription not found"**: Verify the subscription ID in the JSON matches your Azure subscription

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

### Active Workflows (in .github/workflows/)

#### 1. Development Build & Deploy (dev_mysamplewebapp001.yml)
- **Location:** `.github/workflows/dev_mysamplewebapp001.yml`
- **Trigger:** Push to `dev` branch or manual
- **Actions:**
  - Builds Docker image
  - Tags: `dev-{full-sha}` and `latest`
  - Deploys the specific `dev-{full-sha}` tag to production
- **Note:** Deploys specific version for traceability, not `latest`

#### 2. Release Build & Deploy (release-deploy.yml)
- **Location:** `.github/workflows/release-deploy.yml`
- **Trigger:** Git tag matching `v*.*.*` (e.g., v1.0.0) or manual
- **Can trigger from:** Command line OR GitHub UI (both work identically)
- **Actions:**
  - Builds Docker image
  - Tags: `v1.0.0`, `latest`, and `{commit-sha}`
  - Deploys the semantic version tag to production
- **Creating a release (two methods):**
  - **Command line:**
    ```bash
    git tag v1.0.0
    git push origin v1.0.0
    ```
  - **GitHub UI:** Releases → Draft a new release → Create tag → Publish
    - Recommended for better visibility and release notes

#### 3. ACR Tag Cleanup (cleanup_acr.yml)
- **Location:** `.github/workflows/acr-cleanup.yml`
- **Schedule:** Every 30 minutes
- **Purpose:** Removes old ephemeral tags, keeps semantic versions

#### 4. ACR Untagged Images Cleanup (purge_acr_untagged.yml)
- **Location:** `.github/workflows/acr-purge-untagged.yml`
- **Schedule:** Daily at 2 AM UTC
- **Purpose:** Removes orphaned image layers

### Optional Workflow (in misc/ folder - not active)

#### Multi-Branch Build with PR Support (build-push.yml)
- **Location:** `misc/build-push.yml` (needs to be moved to activate)
- **Trigger:** Push to any branch or pull request
- **Actions:**
  - Builds and pushes images with ephemeral tags
  - Creates `pr-{number}` tags for pull requests
  - Deploys to dev environment only when pushing to `dev` branch
  
**To activate PR tagging:**
```bash
# Copy to workflows folder
cp misc/build-push.yml .github/workflows/build-push.yml
git add .github/workflows/build-push.yml
git commit -m "Enable PR tagging workflow"
git push
```

**To test PR tags:**
1. Create a feature branch: `git checkout -b feature/test-pr`
2. Make changes and push: `git push origin feature/test-pr`
3. Open a Pull Request via GitHub UI
4. Workflow creates image tagged as `pr-{PR-number}`
5. Verify: `az acr repository show-tags --name mysampleacr --repository sample-app | grep pr-`

---

## Checking Deployment & Logs

- Visit your web app URL.
- Tail logs:
        ```sh
        az webapp log tail -g <RG> -n <WEBAPP_NAME>
        ```

---

## Cleanup Workflows

### 1. ACR Tag Cleanup (cleanup_acr.yml)
- **Schedule:** Daily at 3 AM UTC
- **Purpose:** Removes old ephemeral tags, keeps semantic versions forever
- **What it does:**
  - Preserves ALL semantic version tags (v1.0.0, v2.1.3, etc.)
  - Keeps only last 5 ephemeral tags (dev-xxx, main-xxx, pr-xxx)
  - Deletes older ephemeral tags to reduce storage costs

### 2. ACR Untagged Images Cleanup (purge_acr_untagged.yml)
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
gh workflow run "ACR - Cleanup" --ref dev

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

 **sample GitHub Actions workflow YAML** that uses **conditional filters** (`on.push.branches` and `on.pull_request.paths`) to avoid unnecessary builds. This way, your CI/CD pipeline only runs when relevant files or branches are updated.

---

## 📝 Sample Workflow: Conditional Build & Deploy

```yaml
name: CI/CD Pipeline

on:
  push:
    branches:
      - main         # Only run on pushes to main
      - dev          # Also run on dev branch
    paths:
      - 'src/**'     # Only trigger if files in src/ change
      - '.github/workflows/**' # Trigger if workflow files change
  pull_request:
    branches:
      - main         # Run checks for PRs targeting main
    paths:
      - 'src/**'     # Only run if PR changes code in src/
      - 'tests/**'   # Or if PR changes test files

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'

      - name: Install dependencies
        run: npm install

      - name: Run tests
        run: npm test

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'   # Only deploy from main branch
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Deploy to Azure Web App
        uses: azure/webapps-deploy@v2
        with:
          app-name: my-sample-app
          publish-profile: ${{ secrets.AZURE_WEBAPP_PUBLISH_PROFILE }}
          package: .
```

---

## 🔎 Key Highlights
- **`on.push.branches`** → restricts builds to `main` and `dev`.  
- **`on.push.paths`** → only triggers if files in `src/` or workflow configs change.  
- **`on.pull_request.paths`** → ensures PR builds only run if code or tests are touched.  
- **`if: github.ref == 'refs/heads/main'`** → deploy job runs only when pushing to `main`.  

---

✅ This setup avoids unnecessary builds when unrelated files (like docs or README) are changed.  

Would you like me to extend this sample to also include a **scheduled nightly build (`on.schedule`)** so you can catch issues even if no one pushes code during the day?

## ACR Cleanup & Purge Scripts and Workflows

- **Script Names Updated:**
    - Tag cleanup script: `infra/cleanup_acr.sh`
    - Untagged manifest purge script: `infra/purge_acr.sh`
- **Workflow Names Updated:**
    - Tag cleanup workflow: `.github/workflows/cleanup-acr.yml`
    - Untagged manifest purge workflow: `.github/workflows/purge-acr-untagged.yml`
- **Azure CLI Syntax Fix:**
    - Tag deletion now uses: `az acr repository delete --name <ACR> --image <REPO>:<TAG> --yes`
    - Previous (incorrect) usage: `--tag <TAG>` (now fixed)
- **Retention Logic:**
    - All semantic version tags (`v*.*.*` or `V*.*.*`, case-insensitive) are kept forever
    - Only the most recent 5 ephemeral tags are retained; older ephemeral tags are deleted
    - Untagged manifests are purged daily if older than 2 days
- **Script Output:**
    - Tag cleanup script now prints errors for failed deletions and shows which tags are kept/deleted
    - Purge script shows manifest-level summary (untagged images)

## Infrastructure Scripts Summary & Usage

### 1. `infra/create-resources.sh`
- **Purpose:** Provision Azure resources (ACR, App Service Plan, Web App) for dev/prod.
- **Usage:**
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
- **Usage:**
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
- **Usage:**
    ```bash
    bash infra/purge_acr.sh <REGISTRY_NAME> <REPOSITORY_NAME> <AGO_DAYS> [--dry-run]
    # Example:
    bash infra/purge_acr.sh mysampleacr sample-app 2 --dry-run
    ```
- **Troubleshooting:**
    - Must have `AcrDelete` or `Contributor` role
    - Run `az login` before running
    - Only shows manifest-level summary (untagged images)
