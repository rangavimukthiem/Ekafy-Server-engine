#!/bin/bash
set -euo pipefail

########################################
# Ekafy Server Engine – Init (ONE TIME)
########################################

# ---------- Constants ----------
EKAFY_DIR="/srv/ekafy-server-engine"
INIT_FLAG="$EKAFY_DIR/.initialized"

EKAFY_USER="ekafy"
EKAFY_GROUP="ekafy"

REGISTRY_DB="ekafy_registry"
REGISTRY_USER="ekafy_admin"
REGISTRY_SECRET="$EKAFY_DIR/secrets/registry-db.env"

# ---------- Root Check ----------
if [[ "$EUID" -ne 0 ]]; then
  echo "❌ This command must be run as root"
  echo "👉 Use: sudo ekafy init"
  exit 1
fi

# ---------- Idempotency Guard ----------
if [[ -f "$INIT_FLAG" ]]; then
  echo "⚠️  Ekafy is already initialized."
  echo "✔ Nothing to do. Exiting safely."
  exit 0
fi

echo "===================================="
echo "   Ekafy Server Engine - Init"
echo "===================================="
echo ""

# ---------- Collect Info ----------
read -rp "Server name        : " SERVER_NAME
read -rp "Admin email        : " ADMIN_EMAIL

# ---------- Timezone ----------
DETECTED_TZ=$(timedatectl show --property=Timezone --value 2>/dev/null || true)
TIMEZONE="${DETECTED_TZ:-Etc/UTC}"
echo "🕒 Timezone set to : $TIMEZONE"
timedatectl set-timezone "$TIMEZONE"

# ---------- Helper: Check Command ----------
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# ---------- Install Base Packages ----------
echo ""
echo "📦 Installing base packages..."

apt update -y

for pkg in curl git ca-certificates nginx; do
  if dpkg -s "$pkg" &>/dev/null; then
    echo "✔ $pkg already installed"
  else
    echo "⬇ Installing $pkg..."
    apt install -y "$pkg"
  fi
done

# ---------- PostgreSQL ----------
echo ""
echo "🗄️ Checking PostgreSQL..."

if command_exists psql; then
  echo "✔ PostgreSQL already installed"
else
  echo "⬇ Installing PostgreSQL..."
  apt install -y postgresql postgresql-contrib
fi

systemctl enable --now postgresql
systemctl enable --now nginx

# ---------- Node.js + npm ----------
echo ""
echo "🟢 Checking Node.js..."

if command_exists node; then
  echo "✔ Node.js installed: $(node -v)"
else
  echo "⬇ Installing Node.js (LTS)..."
  curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
  apt install -y nodejs
fi

echo "📦 Checking npm..."

if command_exists npm; then
  echo "✔ npm installed: $(npm -v)"
else
  echo "⬇ Installing npm..."
  apt install -y npm
fi

# ---------- PM2 ----------
echo ""
echo "⚙️ Checking PM2..."

if command_exists pm2; then
  echo "✔ PM2 already installed"
else
  echo "⬇ Installing PM2..."
  npm install -g pm2
  pm2 startup systemd
fi

# ---------- Express (global optional) ----------
echo ""
echo "🚀 Checking Express..."

if npm list -g express &>/dev/null; then
  echo "✔ Express already installed globally"
else
  echo "⬇ Installing Express globally..."
  npm install -g express
fi

# ---------- Ensure Group Exists ----------
if ! getent group "$EKAFY_GROUP" >/dev/null; then
  groupadd "$EKAFY_GROUP"
fi

# ---------- Create Ekafy System User ----------
echo ""
echo "👤 Creating Ekafy system user..."

if ! id "$EKAFY_USER" &>/dev/null; then
  useradd -r -g "$EKAFY_GROUP" -s /usr/sbin/nologin "$EKAFY_USER"
fi

# ---------- Create Directories ----------
echo ""
echo "📁 Creating Ekafy directories..."

mkdir -p "$EKAFY_DIR"/{apps,logs,secrets,config,core}

# ---------- Permissions ----------
echo "🔐 Setting permissions..."

chown root:"$EKAFY_GROUP" "$EKAFY_DIR/apps"
chmod 775 "$EKAFY_DIR/apps"

chown -R "$EKAFY_USER":"$EKAFY_GROUP" \
  "$EKAFY_DIR"/{logs,secrets,config,core}

chmod 755 "$EKAFY_DIR"
chmod 755 "$EKAFY_DIR"/{logs,core}
chmod 750 "$EKAFY_DIR"/{config,secrets}

# ---------- Save Server Config ----------
echo ""
echo "📝 Writing server configuration..."

cat > "$EKAFY_DIR/config/server.env" <<EOF
SERVER_NAME="$SERVER_NAME"
ADMIN_EMAIL="$ADMIN_EMAIL"
TIMEZONE="$TIMEZONE"
EOF

chmod 640 "$EKAFY_DIR/config/server.env"
chown "$EKAFY_USER":"$EKAFY_GROUP" "$EKAFY_DIR/config/server.env"

# ---------- PostgreSQL Registry Setup ----------


echo ""
echo "🗄️ Setting up Ekafy registry database..."

REGISTRY_PASS=$(openssl rand -hex 16)

# Use /tmp to avoid permission issues
sudo -u postgres bash <<EOF
cd /tmp || exit 1

# ---- Create role if it doesn't exist ----
psql -tc "SELECT 1 FROM pg_roles WHERE rolname='${REGISTRY_USER}'" | grep -q 1 || \
psql -c "CREATE ROLE \"${REGISTRY_USER}\" LOGIN PASSWORD '${REGISTRY_PASS}';"

# ---- Create database if it doesn't exist ----
psql -tc "SELECT 1 FROM pg_database WHERE datname='${REGISTRY_DB}'" | grep -q 1 || \
psql -c "CREATE DATABASE \"${REGISTRY_DB}\" OWNER \"${REGISTRY_USER}\";"
EOF

# ---------- Save DB Secret ----------
install -d -m 700 "$EKAFY_DIR/secrets"

cat > "$REGISTRY_SECRET" <<EOF
ADMIN_EMAIL=${ADMIN_EMAIL}
DB_TYPE=postgres
DB_HOST=localhost
DB_PORT=5432
DB_NAME=${REGISTRY_DB}
DB_USER=${REGISTRY_USER}
DB_PASSWORD=${REGISTRY_PASS}
EOF

chmod 600 "$REGISTRY_SECRET"
chown "$EKAFY_USER:$EKAFY_GROUP" "$REGISTRY_SECRET"

# ---------- Create Registry Tables ----------
sudo -u postgres psql -d "$REGISTRY_DB" -c "
CREATE TABLE IF NOT EXISTS apps (
  id UUID PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  has_api BOOLEAN DEFAULT false,
  has_db BOOLEAN DEFAULT false,
  has_web BOOLEAN DEFAULT false,
  repo TEXT,
  db_name TEXT,
  db_user TEXT,
  api_port INTEGER,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);"

# ---------- Mark Initialization ----------
touch "$INIT_FLAG"
chmod 640 "$INIT_FLAG"
chown "$EKAFY_USER":"$EKAFY_GROUP" "$INIT_FLAG"

echo ""
echo "✅ Ekafy initialization completed successfully!"
echo "------------------------------------"
echo "Server Name : $SERVER_NAME"
echo "Admin Email : $ADMIN_EMAIL"
echo "Timezone    : $TIMEZONE"
echo "Registry DB : $REGISTRY_DB"
echo "------------------------------------"