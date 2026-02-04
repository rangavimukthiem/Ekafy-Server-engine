#!/bin/bash

set -e

echo "===================================="
echo "   Ekafy Server Engine - Init"
echo "===================================="
echo ""

# Ensure root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root (use sudo ekafy init)"
  exit 1
fi

# Collect basic info
read -p "Server name: " SERVER_NAME
read -p "Admin email: " ADMIN_EMAIL
read -p "Timezone [UTC]: " TIMEZONE
TIMEZONE=${TIMEZONE:-UTC}

echo ""
echo "🔧 Configuring server..."

# Set timezone
timedatectl set-timezone "$TIMEZONE"

# Update system
apt update -y
apt upgrade -y

# Create Ekafy directories
mkdir -p /srv/ekafy-server-engine/{apps,logs,secrets,config}

# Save config
cat > /srv/ekafy-server-engine/config/server.env <<EOF
SERVER_NAME="$SERVER_NAME"
ADMIN_EMAIL="$ADMIN_EMAIL"
TIMEZONE="$TIMEZONE"
EOF

chmod 600 /srv/ekafy-server-engine/config/server.env

echo ""
echo "✅ Ekafy initialization completed!"
echo "Server Name : $SERVER_NAME"
echo "Admin Email : $ADMIN_EMAIL"
echo "Timezone    : $TIMEZONE"

