#!/bin/bash

echo "========================================"
echo "   Algolia Search Index Update Tool    "
echo "========================================"
echo ""

# 提示输入 Admin API Key
echo "This script will update the Algolia search index."
echo "You need to provide the Algolia Admin API Key."
echo ""
echo "Get your Admin API Key from:"
echo "  https://www.algolia.com/dashboard -> Settings -> API Keys"
echo ""

read -sp "Enter Algolia Admin API Key: " ALGOLIA_KEY
echo ""

if [ -z "$ALGOLIA_KEY" ]; then
    echo "ERROR: API Key cannot be empty!"
    exit 1
fi

echo ""
echo "Step 1: Cleaning previous build..."
hexo clean

if [ $? -ne 0 ]; then
    echo "ERROR: hexo clean failed!"
    exit 1
fi

echo "Step 2: Generating site content..."
hexo generate

if [ $? -ne 0 ]; then
    echo "ERROR: hexo generate failed!"
    exit 1
fi

echo "Step 3: Updating Algolia index..."
export HEXO_ALGOLIA_INDEXING_KEY="$ALGOLIA_KEY"
hexo algolia

if [ $? -ne 0 ]; then
    echo "ERROR: Algolia index update failed!"
    echo "Possible causes:"
    echo "  - Invalid Admin API Key"
    echo "  - Network connection issue"
    echo "  - Algolia API rate limit exceeded"
    exit 1
fi

echo ""
echo "========================================"
echo "   Algolia Index Updated Successfully!   "
echo "========================================"
echo ""
echo "You can verify the update at:"
echo "  https://www.algolia.com/dashboard"
echo ""

# 清除环境变量
unset HEXO_ALGOLIA_INDEXING_KEY