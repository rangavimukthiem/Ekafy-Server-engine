ekafy_status() {

    BASE="/srv/core"
    INIT_FLAG="$BASE/.initialized"
    REGISTRY_DB="ekafy_registry"

    echo ""
    echo "===================================="
    echo "🚀 EKAFY ENGINE STATUS"
    echo "===================================="

    # -------------------------
    # Initialization check
    # -------------------------
    if [[ -f "$INIT_FLAG" ]]; then
        echo "Status        : ✅ Initialized"
    else
        echo "Status        : ❌ Not Initialized"
        echo "------------------------------------"
        return 1
    fi

    # -------------------------
    # Apps count from PostgreSQL
    # -------------------------
    if command -v psql >/dev/null 2>&1; then

        APP_COUNT=$(sudo -u postgres psql -d "$REGISTRY_DB" -t -A -c \
        "SELECT COUNT(*) FROM apps;" 2>/dev/null || echo "0")

        echo "Apps          : $APP_COUNT"

    else
        echo "Apps          : ❌ PostgreSQL not available"
    fi

    # -------------------------
    # Reserved ports usage
    # -------------------------
    if command -v psql >/dev/null 2>&1; then

        USED_PORTS=$(sudo -u postgres psql -d "$REGISTRY_DB" -t -A -c \
        "SELECT COUNT(*) FROM reserved_ports WHERE allocated = true;" 2>/dev/null || echo "0")

        echo "Allocated Ports: $USED_PORTS"

    fi

    # -------------------------
    # PM2 status
    # -------------------------
    if command -v pm2 >/dev/null 2>&1; then
        echo ""
        echo "📦 PM2 STATUS"
        pm2 list | sed 's/^/  /'
    else
        echo "PM2           : ❌ Not installed"
    fi

    # -------------------------
    # Nginx status
    # -------------------------
    echo ""
    echo "🌐 NGINX STATUS"

    if systemctl is-active --quiet nginx; then
        echo "Nginx         : ✅ Running"
    else
        echo "Nginx         : ❌ Stopped"
    fi

    # -------------------------
    # Disk usage (optional useful)
    # -------------------------
    echo ""
    echo "💾 DISK USAGE (/srv/core)"
    du -sh "$BASE" 2>/dev/null

    echo ""
    echo "===================================="
}