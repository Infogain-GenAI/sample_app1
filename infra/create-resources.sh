
#!/usr/bin/env bash
# Enable strict error handling:
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error and exit immediately.
# -o pipefail: Return the exit status of the last command in the pipeline that failed.
set -euo pipefail

RG=${RG:-mysamplerg}
LOCATION=${LOCATION:-centralindia}
ACR_NAME=${ACR_NAME:-mysampleacr}
PLAN_NAME=${PLAN_NAME:-mysampleplan}
WEBAPP_NAME=${WEBAPP_NAME:-mysamplewebapp001}

echo "Using configuration:"
echo "  Resource Group: $RG"
echo "  Location: $LOCATION"
echo "  ACR Name: $ACR_NAME"
echo "  Plan Name: $PLAN_NAME"
echo "  Web App Name: $WEBAPP_NAME"
echo ""

#az login --use-device-code

echo "Creating resource group..."
az group create --name "$RG" --location "$LOCATION"

echo "Creating Azure Container Registry..."
az acr create --name "$ACR_NAME" --resource-group "$RG" --sku Standard

echo "Enabling ACR admin access..."
az acr update -n "$ACR_NAME" --admin-enabled true

echo "Retrieving ACR credentials..."
LOGIN_SERVER=$(az acr show -n "$ACR_NAME" --query loginServer -o tsv)
USER=$(az acr credential show -n "$ACR_NAME" --query username -o tsv)
PASS=$(az acr credential show -n "$ACR_NAME" --query passwords[0].value -o tsv)

echo "Creating App Service Plan..."
az appservice plan create --name "$PLAN_NAME" --resource-group "$RG" --is-linux --sku B1

echo "Creating Web App..."
az webapp create --name "$WEBAPP_NAME" --resource-group "$RG" --plan "$PLAN_NAME" --deployment-container-image-name nginx:latest

echo "Waiting for Web App to be ready..."
sleep 10

echo "Configuring Web App container settings..."
az webapp config container set \
  --name "$WEBAPP_NAME" --resource-group "$RG" \
  --docker-custom-image-name "$LOGIN_SERVER/sample-app:latest" \
  --docker-registry-server-url "https://$LOGIN_SERVER" \
  --docker-registry-server-user "$USER" \
  --docker-registry-server-password "$PASS"

echo "Setting Web App configuration..."
az webapp config appsettings set \
  --name "$WEBAPP_NAME" --resource-group "$RG" \
  --settings APP_NAME=sample-app DB_PATH=/home/site/wwwroot/data/app.db SECRET_KEY=prod-secret PORT=8000

echo ""
echo "Resources created successfully!"
echo "  Web App URL: https://$WEBAPP_NAME.azurewebsites.net"
echo "  ACR Login Server: $LOGIN_SERVER"
echo ""


# needs premium sku
# az acr config retention update --registry "$ACR_NAME" --status enabled --days 2 --type UntaggedManifests


# Microsoft provides a sample task called acr-purge (via ACR Tasks) that can be scheduled to clean up untagged images  even without Premium retention:

az acr task create \
  --registry "$ACR_NAME" \
  --name purge-untagged \
  --cmd "acr purge --filter '.*:.*' --untagged --ago 2d" \
  --schedule "0 0 * * *" \
  --context /dev/null