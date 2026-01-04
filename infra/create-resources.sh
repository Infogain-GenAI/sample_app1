
#!/usr/bin/env bash
# Enable strict error handling:
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error and exit immediately.
# -o pipefail: Return the exit status of the last command in the pipeline that failed.
#set -euo pipefail

RG=${RG:-mysamplerg}
LOCATION=${LOCATION:-centralindia}

# DEV Environment Resources
DEV_ACR_NAME=${DEV_ACR_NAME:-mysampleacr}
DEV_PLAN_NAME=${DEV_PLAN_NAME:-mysampleplan}
DEV_WEBAPP_NAME=${DEV_WEBAPP_NAME:-mysamplewebapp001}

# PROD Environment Resources
PROD_ACR_NAME=${PROD_ACR_NAME:-mysampleprodacr}
PROD_PLAN_NAME=$DEV_PLAN_NAME
PROD_WEBAPP_NAME=${PROD_WEBAPP_NAME:-mysamplewebapp001-prod}

echo "Using configuration:"
echo "  Resource Group: $RG"
echo "  Location: $LOCATION"
echo ""
echo "DEV Environment:"
echo "  ACR Name: $DEV_ACR_NAME"
echo "  Plan Name: $DEV_PLAN_NAME"
echo "  Web App Name: $DEV_WEBAPP_NAME"
echo ""
echo "PROD Environment:"
echo "  ACR Name: $PROD_ACR_NAME"
echo "  Plan Name: $PROD_PLAN_NAME"
echo "  Web App Name: $PROD_WEBAPP_NAME"
echo ""

#az login --use-device-code

echo "Creating resource group..."
az group create --name "$RG" --location "$LOCATION"

echo ""
echo "=========================================="
echo "Creating DEV Environment Resources"
echo "=========================================="
echo ""

echo "Creating DEV Azure Container Registry..."
az acr create --name "$DEV_ACR_NAME" --resource-group "$RG" --sku Standard

echo "Enabling DEV ACR admin access..."
az acr update -n "$DEV_ACR_NAME" --admin-enabled true

echo "Retrieving DEV ACR credentials..."
DEV_LOGIN_SERVER=$(az acr show -n "$DEV_ACR_NAME" --query loginServer -o tsv)
DEV_USER=$(az acr credential show -n "$DEV_ACR_NAME" --query username -o tsv)
DEV_PASS=$(az acr credential show -n "$DEV_ACR_NAME" --query passwords[0].value -o tsv)

echo "Creating DEV App Service Plan..."
az appservice plan create --name "$DEV_PLAN_NAME" --resource-group "$RG" --is-linux --sku B1

echo "Creating DEV Web App..."
az webapp create --name "$DEV_WEBAPP_NAME" --resource-group "$RG" --plan "$DEV_PLAN_NAME" --deployment-container-image-name nginx:latest

echo "Waiting for DEV Web App to be ready..."
sleep 10

echo "Configuring DEV Web App container settings..."
az webapp config container set \
  --name "$DEV_WEBAPP_NAME" --resource-group "$RG" \
  --docker-custom-image-name "$DEV_LOGIN_SERVER/sample-app:latest" \
  --docker-registry-server-url "https://$DEV_LOGIN_SERVER" \
  --docker-registry-server-user "$DEV_USER" \
  --docker-registry-server-password "$DEV_PASS"

echo "=========================================="
echo "Configuring ACR Cleanup Tasks"
echo "=========================================="
echo ""

# Configure ACR purge task for DEV ACR (cleans up untagged images)
echo "Setting up DEV ACR purge task for untagged images..."
az acr task create \
  --registry "$DEV_ACR_NAME" \
  --name purge-untagged-dev \
  --cmd "acr purge --filter '.*:.*' --untagged --ago 2d" \
  --schedule "0 0 * * *" \
  --context /dev/null

# PROD ACR: No automatic cleanup - keep all release images
echo "PROD ACR: Keeping all images (no automatic cleanup configured)"

echo ""
echo "=========================================="
echo " All Resources Created Successfully!"
echo "=========================================="
echo ""
echo "DEV Environment:"
echo "  Web App URL: https://$DEV_WEBAPP_NAME.azurewebsites.net"
echo "  ACR Login Server: $DEV_LOGIN_SERVER"
echo "  ACR Username: $DEV_USER"
echo "  ACR Password: $DEV_PASS"
echo ""
echo "PROD Environment:"
echo "  Web App URL: https://$PROD_WEBAPP_NAME.azurewebsites.net"
echo "  ACR Login Server: $PROD_LOGIN_SERVER"
echo "  ACR Username: $PROD_USER"
echo "  ACR Password: $PROD_PASS"
echo ""
echo "=========================================="
echo "GitHub Secrets to Configure"
echo "=========================================="
echo ""
echo "Update these secrets in GitHub repository:"
echo ""
echo "DEV ACR Credentials (existing):"
echo "  AZUREAPPSERVICE_CONTAINERUSERNAME_xxx: $DEV_USER"
echo "  AZUREAPPSERVICE_CONTAINERPASSWORD_xxx: $DEV_PASS"
echo ""
echo "PROD ACR Credentials (new):"
echo "  PROD_ACR_USERNAME: $PROD_USER"
echo "  PROD_ACR_PASSWORD: $PROD_PASS"
echo "  PROD_ACR_LOGIN_SERVER: $PROD_LOGIN_SERVER"
echo ""
echo "PROD Web App Publish Profile (new):"
echo "  1. Go to Azure Portal → $PROD_WEBAPP_NAME"
echo "  2. Click 'Get publish profile' button"
echo "  3. Add as secret: PROD_WEBAPP_PUBLISHPROFILE"


echo "Creating PROD Azure Container Registry..."
az acr create --name "$PROD_ACR_NAME" --resource-group "$RG" --sku Standard

echo "Enabling PROD ACR admin access..."
az acr update -n "$PROD_ACR_NAME" --admin-enabled true
echo "Retrieving PROD ACR credentials..."

echo " ACR credentials..."
PROD_LOGIN_SERVER=$(az acr show -n "$PROD_ACR_NAME" --query loginServer -o tsv)
PROD_USER=$(az acr credential show -n "$PROD_ACR_NAME" --query username -o tsv)
PROD_PASS=$(az acr credential show -n "$PROD_ACR_NAME" --query passwords[0].value -o tsv)

# echo "Creating PROD App Service Plan... We will use dev plan for now"
# az appservice plan create --name "$PROD_PLAN_NAME" --resource-group "$RG" --is-linux --sku B1

echo "Creating PROD Web App..."
az webapp create --name "$PROD_WEBAPP_NAME" --resource-group "$RG" --plan "$PROD_PLAN_NAME" --deployment-container-image-name nginx:latest

echo "Waiting for PROD Web App to be ready..."
sleep 10

echo "Configuring PROD Web App container settings..."
az webapp config container set \
  --name "$PROD_WEBAPP_NAME" --resource-group "$RG" \
  --docker-custom-image-name "$PROD_LOGIN_SERVER/sample-app:latest" \
  --docker-registry-server-url "https://$PROD_LOGIN_SERVER" \
  --docker-registry-server-user "$PROD_USER" \
  --docker-registry-server-password "$PROD_PASS"

echo "Setting PROD Web App configuration..."
az webapp config appsettings set \
  --name "$PROD_WEBAPP_NAME" --resource-group "$RG" \
  --settings APP_NAME=sample-app-prod DB_PATH=/home/site/wwwroot/data/app.db SECRET_KEY=prod-secret-key PORT=8000 ENVIRONMENT=production

echo ""
echo "Resources created successfully!"
echo "  Web App URL: https://$WEBAPP_NAME.azurewebsites.net"
echo "  ACR Login Server: $LOGIN_SERVER"
echo ""


# needs premium sku
# az acr config retention update --registry "$DEV_ACR_NAME" --status enabled --days 2 --type UntaggedManifests
# az acr config retention update --registry "$PROD_ACR_NAME" --status enabled --days 2 --type UntaggedManifests

# Microsoft provides a sample task called acr-purge (via ACR Tasks) that can be scheduled to clean up untagged images  even without Premium retention:

az acr task create \
  --registry "$DEV_ACR_NAME" \
  --name purge-untagged \
  --cmd "acr purge --filter '.*:.*' --untagged --ago 2d" \
  --schedule "0 0 * * *" \
  --context /dev/null


  
az acr task create \
  --registry "$PROD_ACR_NAME" \
  --name purge-untagged \
  --cmd "acr purge --filter '.*:.*' --untagged --ago 2d" \
  --schedule "0 0 * * *" \
  --context /dev/null