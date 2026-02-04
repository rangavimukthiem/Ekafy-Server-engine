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

# Auto-detect timezone
DETECTED_TZ=$(timedatectl show --property=Timezone --value 2>/dev/null || true)

if [ -z "$DETECTED_TZ" ]; then
  echo "⚠️  Unable to detect timezone automatically."
  read -p "Enter timezone (e.g. Asia/Colombo) [UTC]: " TIMEZONE
  TIMEZONE=${TIMEZONE:-Etc/UTC}
else
  TIMEZONE="$DETECTED_TZ"
  echo "🕒 Timezone detected: $TIMEZONE"
fi

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

