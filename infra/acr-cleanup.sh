#!/bin/bash
# ACR Cleanup Script
# Run this script from an Azure VM or any machine with Azure CLI installed
# This implements the same cleanup logic 
#
# Usage:
#   bash acr-cleanup.sh [REGISTRY_NAME] [REPOSITORY_NAME] [KEEP_COUNT]
#
# Examples:
#   bash acr-cleanup.sh mysampleacr sample-app 5
#   bash acr-cleanup.sh mysampleacr sample-app        # Uses default keep_count=5
#
# Prerequisites:
#   - Azure CLI installed (az command)
#   - Logged in to Azure (run: az login)
#   - Permissions to manage ACR (Contributor or AcrDelete role)

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
KEEP_COUNT="${3:-5}"  # Keep last N ephemeral tags

echo -e "${BLUE}=== ACR Cleanup ===${NC}"
echo "Registry: $REGISTRY_NAME"
echo "Repository: $REPOSITORY_NAME"
echo "Keep last: $KEEP_COUNT ephemeral tags"
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
echo ""

# Verify repository exists
echo -e "${BLUE}Verifying repository...${NC}"
if ! az acr repository show --name "$REGISTRY_NAME" --repository "$REPOSITORY_NAME" &> /dev/null; then
    echo -e "${RED} Error: Repository '$REPOSITORY_NAME' not found in ACR${NC}"
    exit 1
fi
echo -e "${GREEN} Repository exists${NC}"
echo ""

# Step 1: List all tags and separate semantic versions from ephemeral tags
echo -e "${BLUE}Step 1: Analyzing tags...${NC}"
ALL_TAGS=$(az acr repository show-tags \
    --name "$REGISTRY_NAME" \
    --repository "$REPOSITORY_NAME" \
    --orderby time_desc \
    --output tsv 2>/dev/null || echo "")

if [ -z "$ALL_TAGS" ]; then
    echo -e "${YELLOW} No tags found in repository${NC}"
    exit 0
fi

# Separate semantic version tags (v*.*.* - these are kept forever)
SEMANTIC_TAGS=$(echo "$ALL_TAGS" | grep '^v' || true)
SEMANTIC_COUNT=$(echo "$SEMANTIC_TAGS" | grep -c . || echo 0)

# Separate ephemeral tags (dev-xxx, main-xxx, pr-xxx, etc.)
EPHEMERAL_TAGS=$(echo "$ALL_TAGS" | grep -v '^v' | grep -v '^latest$' || true)
EPHEMERAL_COUNT=$(echo "$EPHEMERAL_TAGS" | grep -c . || echo 0)

echo -e "${GREEN} Found tags:${NC}"
echo "  Semantic versions (kept forever): $SEMANTIC_COUNT"
echo "  Ephemeral tags (keep last $KEEP_COUNT): $EPHEMERAL_COUNT"
echo ""

# Step 2: Determine which ephemeral tags to delete
if [ "$EPHEMERAL_COUNT" -le "$KEEP_COUNT" ]; then
    echo -e "${GREEN} Ephemeral tag count ($EPHEMERAL_COUNT) is within limit ($KEEP_COUNT)${NC}"
    echo "No cleanup needed."
    echo ""
    
    # Show what's being kept
    echo -e "${BLUE}Tags being retained:${NC}"
    echo "$EPHEMERAL_TAGS" | head -n "$KEEP_COUNT" | sed 's/^/  - /'
    exit 0
fi

# Calculate tags to delete (everything beyond KEEP_COUNT)
TAGS_TO_DELETE=$(echo "$EPHEMERAL_TAGS" | tail -n +$((KEEP_COUNT + 1)))
DELETE_COUNT=$(echo "$TAGS_TO_DELETE" | grep -c . || echo 0)

echo -e "${YELLOW} Found $DELETE_COUNT ephemeral tags to delete${NC}"
echo ""

# Step 3: Show what will be kept and deleted
echo -e "${GREEN}Keeping (last $KEEP_COUNT ephemeral):${NC}"
echo "$EPHEMERAL_TAGS" | head -n "$KEEP_COUNT" | sed 's/^/  ✓ /'
echo ""

echo -e "${YELLOW}Deleting (older ephemeral):${NC}"
echo "$TAGS_TO_DELETE" | sed 's/^/  ✗ /'
echo ""

# Step 4: Confirm deletion (unless --yes flag is provided)
if [[ "${4:-}" != "--yes" ]]; then
    echo -e "${YELLOW}Press Enter to continue with deletion, or Ctrl+C to cancel...${NC}"
    read -r
fi

# Step 5: Delete old ephemeral tags
echo -e "${BLUE}Step 2: Deleting old ephemeral tags...${NC}"
DELETED=0
FAILED=0

while IFS= read -r TAG; do
    if [ -z "$TAG" ]; then
        continue
    fi
    
    echo -n "  Deleting tag: $TAG ... "
    if az acr repository delete \
        --name "$REGISTRY_NAME" \
        --repository "$REPOSITORY_NAME" \
        --tag "$TAG" \
        --yes \
        &> /dev/null; then
        echo -e "${GREEN}✓${NC}"
        ((DELETED++))
    else
        echo -e "${RED}✗${NC}"
        ((FAILED++))
    fi
done <<< "$TAGS_TO_DELETE"

echo ""

# Step 6: Show final summary
echo -e "${BLUE}=== Cleanup Summary ===${NC}"
echo -e "${GREEN}Semantic versions kept: $SEMANTIC_COUNT${NC}"
echo -e "${GREEN}Ephemeral tags kept: $KEEP_COUNT${NC}"
echo -e "${YELLOW}Ephemeral tags deleted: $DELETED${NC}"
if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}Failed deletions: $FAILED${NC}"
fi
echo ""

# Show current storage usage (optional)
echo -e "${BLUE}Current ACR storage usage:${NC}"
az acr show-usage --name "$REGISTRY_NAME" --output table || true

echo ""
echo -e "${GREEN}s Cleanup completed successfully${NC}"
