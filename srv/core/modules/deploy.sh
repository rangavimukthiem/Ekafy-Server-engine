function app_deploy() {

    APP="$1"
    PATH="/srv/core/apps/$APP"

    cd "$PATH" || return 1

    echo "📥 Pulling code..."
    git pull origin main || return 1

    echo "📦 Installing deps..."
    cd api && npm install

    echo "🔄 Restarting..."
    pm2 restart "$APP" || pm2 start server.js --name "$APP"

    echo "🧪 Health check..."
    PORT=$(sudo -u postgres psql -d ekafy_registry -t -A -c \
        "SELECT api_port FROM apps WHERE name='$APP';")

    curl -s "http://localhost:$PORT/health" || {
        echo "❌ Failed"
        return 1
    }

    echo "✅ Deployed"
}