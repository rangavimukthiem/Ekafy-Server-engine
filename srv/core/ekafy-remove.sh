#!/bin/bash
set -euo pipefail

echo "Are you sure to Uninstall ?"

EKAFY_DIR="/srv/core"

EKAFY_USER="ekafy"
EKAFY_GROUP="ekafy"

REGISTRY_DB="ekafy_registry"
REGISTRY_USER="ekafy_admin"

echo "===================================="
echo "    Ekafy Server Engine Removal"
echo "===================================="
echo ""

if [[ "$EUID" -ne 0 ]]; then
    echo "❌ Run as root"
    echo "👉 sudo ekafy remove"
    exit 1
fi

read -p "⚠️ Remove Ekafy completely? (y/N): " CONFIRM

if [[ "$CONFIRM" != "y" ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "🛑 Stopping PM2 services..."

pm2 delete all || true
pm2 save || true

echo ""
echo "🌐 Removing nginx configuration..."

rm -f /etc/nginx/sites-enabled/ekafy-gateway
rm -f /etc/nginx/sites-available/ekafy-gateway

nginx -t && systemctl reload nginx || true

echo ""
echo "🗄️ Removing PostgreSQL registry..."

sudo -u postgres psql <<EOF
DROP DATABASE IF EXISTS ${REGISTRY_DB};
DROP ROLE IF EXISTS ${REGISTRY_USER};
EOF

echo ""
echo "👤 Removing Ekafy system user..."

userdel -r ${EKAFY_USER} 2>/dev/null || true
groupdel ${EKAFY_GROUP} 2>/dev/null || true

echo ""
echo "📁 Removing Ekafy files..."

rm -rf ${EKAFY_DIR}

echo ""
echo "⚙️ Removing CLI..."

rm -f /usr/local/bin/ekafy

echo ""
echo "✅ Ekafy completely removed."
echo ""