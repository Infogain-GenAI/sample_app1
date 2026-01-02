
#!/usr/bin/env bash
set -euo pipefail

RG=${RG:-my-sample-rg}
LOCATION=${LOCATION:-centralindia}
ACR_NAME=${ACR_NAME:-mysampleacr}
PLAN_NAME=${PLAN_NAME:-mysample-plan}
WEBAPP_NAME=${WEBAPP_NAME:-mysample-webapp}

az group create --name "$RG" --location "$LOCATION"
az acr create --name "$ACR_NAME" --resource-group "$RG" --sku Standard
az appservice plan create --name "$PLAN_NAME" --resource-group "$RG" --is-linux --sku B1
# az webapp create --name "$WEBAPP_NAME" --resource-group "$RG" --plan "$PLAN_NAME" --deployment-container-image-name nginx:latest

LOGIN_SERVER=$(az acr show -n "$ACR_NAME" --query loginServer -o tsv)
USER=$(az acr credential show -n "$ACR_NAME" --query username -o tsv)
PASS=$(az acr credential show -n "$ACR_NAME" --query passwords[0].value -o tsv)

az webapp config container set \
  --name "$WEBAPP_NAME" --resource-group "$RG" \
  --docker-custom-image-name "$LOGIN_SERVER/sample-app:latest" \
  --docker-registry-server-url "https://$LOGIN_SERVER" \
  --docker-registry-server-user "$USER" \
  --docker-registry-server-password "$PASS"

az webapp config appsettings set \
  --name "$WEBAPP_NAME" --resource-group "$RG" \
  --settings APP_NAME=sample-app DB_PATH=/home/site/wwwroot/data/app.db SECRET_KEY=prod-secret PORT=8000

az acr config retention update --registry "$ACR_NAME" --status enabled --days 2 --type UntaggedManifests