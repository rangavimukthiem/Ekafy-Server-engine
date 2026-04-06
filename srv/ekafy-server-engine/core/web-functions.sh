web_dispatch() {
    local APP="$1"
    local ACTION="$2"

    case "$ACTION" in
        install)
            web_install "$APP"
            ;;
        reinstall)
            web_remove "$APP"
            web_install "$APP"
            ;;
        remove)
            web_remove "$APP"
            ;;
        validate)
            web_validate "$APP"
            ;;
        status)
            web_status "$APP"
            ;;
        *)
            echo "Usage:"
            echo "ekafy product <name> web {install|reinstall|remove|validate|status}"
            ;;
    esac
}

# ============================ Load Web env ===============================

load_web_env() {
    local ENV_FILE="/srv/ekafy-server-engine/apps/$1/config/web.env"

    if [[ ! -f "$ENV_FILE" ]]; then
        echo "❌ web.env not found for $1"
        return 1
    fi

    set -a
    source "$ENV_FILE"
    set +a
}

# ============================ Web install ===============================

web_install() {
    local APP="$1"
    load_web_env "$APP" || return 1

    local CONF="/etc/nginx/sites-available/$APP.conf"
    local ENABLED="/etc/nginx/sites-enabled/$APP.conf"

    echo "🌐 Installing web for $APP..."

    API_BLOCK=""
    if [[ "${API_PROXY:-false}" == "true" ]]; then
        API_BLOCK=$(sed "s/{{API_PORT}}/$API_PORT/g" \
            /srv/ekafy-server-engine/core/nginx-templates/api-block.tpl)
    fi

    sed \
        -e "s|{{DOMAIN}}|$DOMAIN|g" \
        -e "s|{{ROOT_DIR}}|$ROOT_DIR|g" \
        -e "s|{{API_BLOCK}}|$API_BLOCK|g" \
        /srv/ekafy-server-engine/core/nginx-templates/app-web.conf.tpl \
        > "$CONF"

    ln -sf "$CONF" "$ENABLED"

    nginx -t && systemctl reload nginx

    echo "✅ Web installed for $APP"
}

# ============================ Web Remove ===============================

web_remove() {
    local APP="$1"

    rm -f /etc/nginx/sites-enabled/$APP.conf
    rm -f /etc/nginx/sites-available/$APP.conf

    nginx -t && systemctl reload nginx

    echo "🗑 Web removed for $APP"
}

# ============================ Web Validate =============================

web_validate() {
    echo "🔍 Validating Nginx config..."
    nginx -t
}

# ============================ Web Status ===============================

web_status() {
    local APP="$1"
    if [[ -f /etc/nginx/sites-enabled/$APP.conf ]]; then
        echo "✅ Web enabled for $APP"
    else
        echo "❌ Web not enabled for $APP"
    fi
}









