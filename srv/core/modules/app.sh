function app_start() {

    APP="$1"

    PORT=$(sudo -u postgres psql -d ekafy_registry -t -A -c \
        "SELECT api_port FROM apps WHERE name='$APP';")

    cd "/srv/ekafy-server-engine/apps/$APP/api"

    pm2 start server.js --name "$APP" --env PORT="$PORT"

    echo "🚀 Started $APP"
}

function app_stop() {
    pm2 stop "$1"
}

function app_restart() {
    pm2 restart "$1"
}

function app_status() {
    pm2 status "$1"
}