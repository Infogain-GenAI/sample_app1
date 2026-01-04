#!/bin/bash
# ACR Purge Untagged Images Script
# Run this script from an Azure VM or any machine with Azure CLI installed
# Removes untagged manifests (orphaned image layers) to free up storage
#
# Usage:
#   bash acr-purge.sh [REGISTRY_NAME] [REPOSITORY_NAME] [AGO_DAYS] [--dry-run]
#
# Examples:
#   bash acr-purge.sh mysampleacr sample-app 2           # Delete untagged images older than 2 days
#   bash acr-purge.sh mysampleacr sample-app 7           # Delete untagged images older than 7 days
#   bash acr-purge.sh mysampleacr sample-app 2 --dry-run # Dry run (show what would be deleted)
#
# Prerequisites:
#   - Azure CLI installed (az command)
#   - Logged in to Azure (run: az login)
#   - Permissions to manage ACR (Contributor or AcrDelete role)
#   - ACR Tasks enabled (works on Standard and Premium SKU)

set -euo pipefail  # Exit on error, undefined variable, or pipe failure

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration with defaults
REGISTRY_NAME="${1:-mysampleacr}"
REPOSITORY_NAME="${2:-sample-app}"
AGO_DAYS="${3:-2}"  # Delete untagged images older than N days
DRY_RUN="${4:-false}"

# Convert --dry-run flag
if [[ "$DRY_RUN" == "--dry-run" ]]; then
    DRY_RUN="true"
else
    DRY_RUN="false"
fi

echo -e "${BLUE}=== ACR Purge Untagged Images ===${NC}"
echo "Registry: $REGISTRY_NAME"
echo "Repository: $REPOSITORY_NAME"
echo "Age threshold: Older than $AGO_DAYS days"
echo "Mode: $([ "$DRY_RUN" == "true" ] && echo "DRY RUN (no deletion)" || echo "LIVE (will delete)")"
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED} Error: Azure CLI (az) is not installed${NC}"
    echo "Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if logged in to Azure
echo -e "${BLUE}Checking Azure login status...${NC}"
if ! az account show &> /dev/null; then
    echo -e "${RED} Error: Not logged in to Azure${NC}"
    echo "Please run: az login"
    exit 1
fi

CURRENT_SUBSCRIPTION=$(az account show --query name -o tsv)
echo -e "${GREEN} Logged in to Azure${NC}"
echo "  Subscription: $CURRENT_SUBSCRIPTION"
echo ""

# Verify ACR exists
echo -e "${BLUE}Verifying ACR access...${NC}"
if ! az acr show --name "$REGISTRY_NAME" &> /dev/null; then
    echo -e "${RED} Error: Cannot access ACR '$REGISTRY_NAME'${NC}"
    echo "Verify:"
    echo "  1. ACR name is correct"
    echo "  2. You have permissions (Contributor or AcrDelete role)"
    exit 1
fi
echo -e "${GREEN} ACR access verified${NC}"

# Check ACR SKU (Purge works on Standard and Premium)
ACR_SKU=$(az acr show --name "$REGISTRY_NAME" --query sku.name -o tsv)
echo "  SKU: $ACR_SKU"
echo ""

# Verify repository exists
echo -e "${BLUE}Verifying repository...${NC}"
if ! az acr repository show --name "$REGISTRY_NAME" --repository "$REPOSITORY_NAME" &> /dev/null; then
    echo -e "${RED} Error: Repository '$REPOSITORY_NAME' not found in ACR${NC}"
    exit 1
fi
echo -e "${GREEN} Repository exists${NC}"
echo ""

# Show storage usage BEFORE purge
echo -e "${BLUE}Storage usage BEFORE purge:${NC}"
az acr show-usage --name "$REGISTRY_NAME" --output table || true
echo ""

# Prepare purge command
FILTER="${REPOSITORY_NAME}:.*"  # Match all tags in this repository
AGO_PARAM="${AGO_DAYS}d"        # Format: 2d, 7d, etc.
DRY_RUN_FLAG="$([ "$DRY_RUN" == "true" ] && echo "true" || echo "false")"

echo -e "${BLUE}Running ACR purge...${NC}"
if [ "$DRY_RUN" == "true" ]; then
    echo -e "${YELLOW} DRY RUN MODE - Nothing will be deleted${NC}"
fi
echo ""

# Execute purge using ACR Tasks
# This runs as a container in ACR, so it works on Standard SKU
echo "Command: acr purge --filter '$FILTER' --untagged --ago $AGO_PARAM --dry-run $DRY_RUN_FLAG"
echo ""

az acr run \
    --registry "$REGISTRY_NAME" \
    --cmd "acr purge --filter '$FILTER' --untagged --ago $AGO_PARAM --dry-run $DRY_RUN_FLAG" \
    /dev/null

echo ""

# Show storage usage AFTER purge (only if not dry run)
if [ "$DRY_RUN" == "false" ]; then
    echo -e "${BLUE}Storage usage AFTER purge:${NC}"
    az acr show-usage --name "$REGISTRY_NAME" --output table || true
    echo ""
    echo -e "${GREEN} Purge completed successfully${NC}"
else
    echo -e "${YELLOW} Dry run completed - No changes made${NC}"
    echo "Run without --dry-run flag to actually delete untagged images"
fi

echo ""
echo -e "${BLUE}=== Summary ===${NC}"
echo "Registry: $REGISTRY_NAME"
echo "Repository: $REPOSITORY_NAME"
echo "Untagged images older than: $AGO_DAYS days"
echo "Mode: $([ "$DRY_RUN" == "true" ] && echo "Dry run" || echo "Live deletion")"
echo ""

# Show command to run without dry-run
if [ "$DRY_RUN" == "true" ]; then
    echo -e "${YELLOW}To execute the actual purge, run:${NC}"
    echo "  bash $0 $REGISTRY_NAME $REPOSITORY_NAME $AGO_DAYS"
    echo ""
fi
