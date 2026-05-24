ekafy_update() {
    echo "🔄 Updating Ekafy Engine..."

    BASE="/srv/core"
    REPO="https://github.com/YOUR_ORG/ekafy-engine.git"

    # Check if git exists
    if ! command -v git &>/dev/null; then
        echo "📦 Git not found. Installing..."
        sudo apt update && sudo apt install -y git
    fi

    # Ensure directory exists
    if [ ! -d "$BASE" ]; then
        echo "❌ Ekafy is not installed in $BASE"
        exit 1
    fi

    cd "$BASE" || exit 1

    # Backup current version (important safety step)
    BACKUP="/srv/core_backup_$(date +%Y%m%d_%H%M%S)"
    echo "📦 Creating backup at $BACKUP"
    sudo cp -r "$BASE" "$BACKUP"

    # Pull latest changes
    echo "⬇ Pulling latest version from GitHub..."
    sudo git reset --hard
    sudo git pull origin main

    if [ $? -ne 0 ]; then
        echo "❌ Update failed. Restoring backup..."
        sudo rm -rf "$BASE"
        sudo mv "$BACKUP" "$BASE"
        exit 1
    fi

    # Fix permissions
    sudo chmod +x "$BASE"/*.sh
    sudo chmod +x "$BASE"/modules/*.sh

    echo "🔄 Restarting Ekafy services..."

    # Restart gateway if exists
    if command -v pm2 &>/dev/null; then
        pm2 restart all || true
    fi

    echo "✅ Ekafy updated successfully!"
}