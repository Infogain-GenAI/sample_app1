
Semantic versions for releases (never pruned) maintain rollback and audit clarity.

Ephemeral branch/PR tags are rotated to last 5 to keep the registry lean.

Untagged manifests (orphans) are left to ACR’s retention policy (if enabled) — safer than deleting digests directly. 

Unique tags for deployments ensure deterministic rollouts; “stable” tags such as latest remain for convenience but aren’t relied upon for rollbacks.


Secrets to add in GitHub

AZURE_CREDENTIALS – Service Principal JSON with access to ACR (AcrPush) and your Web App (Website Contributor).  
ACR_NAME – the ACR name (without .azurecr.io)
AZURE_WEBAPP_NAME – your web app name
AZURE_RESOURCE_GROUP – resource group
ACR_USERNAME / ACR_PASSWORD – optional (if you follow the CLI deploy flow using registry creds)



How to test the flow

Local dev


python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn backend.main:app --host 0.0.0.0 --port 8000
# browse http://localhost:8000


Build container locally (optional)


docker build -t sample-app:dev .
docker run --rm -p 8000:8000 -e DB_PATH=/data/app.db -v $(pwd)/data:/data sample-app:dev


Create Azure resources
Set RG/LOCATION/ACR/PLAN/WEBAPP and run infra/create-resources.sh.
    
Push repo to GitHub and add secrets.

Open a PR / push to a branch → image built & pushed to ACR with ephemeral tag.

Create a release tag v1.0.0 → image pushed as v1.0.0 and latest; then deployed to App Service.

Check app at your web app URL; tail logs if needed:

az webapp log tail -g <RG> -n <WEBAPP_NAME>.

Nightly cleanup runs automatically (or trigger via Run workflow) and uploads a summary artifact.

