#!/bin/bash

# -------------------------------
# Ekafy Engine Functions
# -------------------------------

function product_create() {
    echo "🚀 Creating new product..."

    read -p "Product name: " PROD_NAME
    read -p "App type (web/api/db): " PROD_TYPE
    read -p "Git repo (optional): " PROD_REPO

    # Create product directories
    PROD_PATH="/srv/ekafy-server-engine/apps/$PROD_NAME"
    sudo mkdir -p "$PROD_PATH"

    echo "📁 Created directory: $PROD_PATH"

    # Optional: clone repo
    if [[ -n "$PROD_REPO" ]]; then
        git clone "$PROD_REPO" "$PROD_PATH"
        echo "🔗 Cloned repo: $PROD_REPO"
    fi

    # Save basic metadata
    cat > "$PROD_PATH/.ekafy_product.env" <<EOF
NAME="$PROD_NAME"
TYPE="$PROD_TYPE"
REPO="$PROD_REPO"
EOF

    echo "✅ Product $PROD_NAME created successfully!"
}

# -------------------------------
# List all products
# -------------------------------
function product_list() {
    APPS_DIR="/srv/ekafy-server-engine/apps"

    # Check if apps directory exists
    if [ ! -d "$APPS_DIR" ]; then
        echo "⚠️ No products found. Directory $APPS_DIR does not exist."
        return
    fi

    # List all products
    PRODUCTS=($(ls -1 "$APPS_DIR"))

    if [ ${#PRODUCTS[@]} -eq 0 ]; then
        echo "ℹ️  No products created yet."
        return
    fi

    echo "📦 Products created by Ekafy:"
    echo "-----------------------------------"
    for PROD in "${PRODUCTS[@]}"; do
        PROD_PATH="$APPS_DIR/$PROD"
        TYPE="Unknown"

        # Try to read type from .ekafy_product.env
        if [ -f "$PROD_PATH/.ekafy_product.env" ]; then
            TYPE=$(grep '^TYPE=' "$PROD_PATH/.ekafy_product.env" | cut -d'=' -f2)
        fi

        echo "• $PROD  [$TYPE]"
    done
    echo "-----------------------------------"
}
# -------------------------------
# Delete a product safely
# -------------------------------
function product_delete() {
    PROD_NAME="$1"

    if [ -z "$PROD_NAME" ]; then
        echo "❌ Please specify the product name to delete."
        echo "Usage: ekafy product delete <product_name>"
        return
    fi

    PROD_PATH="/srv/ekafy-server-engine/apps/$PROD_NAME"

    if [ ! -d "$PROD_PATH" ]; then
        echo "⚠️ Product '$PROD_NAME' does not exist."
        return
    fi

    # Confirm deletion
    echo "⚠️ You are about to delete product '$PROD_NAME' and all its data!"
    read -p "Are you sure? Type 'yes' to confirm: " CONFIRM

    if [ "$CONFIRM" -eq "yes" ]; then
        
        # Delete the product directory
    	rm -rf "$PROD_PATH"
    	echo "✅ Product '$PROD_NAME' deleted successfully!"
       	return
    fi
   	echo "echo ❌ Deletion cancelled."


}

