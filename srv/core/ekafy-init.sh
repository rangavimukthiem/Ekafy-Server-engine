#!/bin/bash
set -euo pipefail

########################################
# Ekafy Server Engine – Init (ONE TIME)
########################################

function allocate_port() {

    PORT=$(sudo -u postgres psql -d "$REGISTRY_DB" -t -A -c "
    UPDATE reserved_ports
    SET allocated = true
    WHERE port = (
        SELECT port
        FROM reserved_ports
        WHERE allocated = false
        LIMIT 1
    )
    RETURNING port;
    ")

    echo "$PORT"
}

# ---------- Constants ----------
SERVER_NAME="Ekafy-Engine"
EKAFY_DIR="/srv/core"
INIT_FLAG="$EKAFY_DIR/.initialized"

EKAFY_USER="ekafy"
EKAFY_GROUP="ekafy"

REGISTRY_DB="ekafy_registry"
REGISTRY_USER="ekafy_admin"
REGISTRY_SECRET="$EKAFY_DIR/secrets/registry-db.env"

# ---------- Root Check ----------
if [[ "$EUID" -ne 0 ]]; then
  echo "❌ This command must be run as root"
  echo "👉 Use: sudo ekafy "
  
  
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
echo	 "Server name	     :  $SERVER_NAME"
read -rp "Admin email        : " ADMIN_EMAIL
read -rp "Server_IP       	 : " SERVER_IP

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

mkdir -p "$EKAFY_DIR"/{apps,logs,secrets,config,gateway}

# ---------- Permissions ----------
echo "🔐 Setting permissions..."

chown root:"$EKAFY_GROUP" "$EKAFY_DIR/apps"
chmod 775 "$EKAFY_DIR/apps"

chown -R "$EKAFY_USER":"$EKAFY_GROUP" \
  "$EKAFY_DIR"/{logs,secrets,config,gateway}

chmod 755 "$EKAFY_DIR"
chmod 755 "$EKAFY_DIR"/{logs,gateway}
chmod 750 "$EKAFY_DIR"/{config,secrets}

# ---------- Save Server Config ----------
echo ""
echo "📝 Writing server configuration..."

cat > "$EKAFY_DIR/config/server.env" <<EOF
SERVER_NAME="$SERVER_NAME"
ADMIN_EMAIL="$ADMIN_EMAIL"
TIMEZONE="$TIMEZONE"
SERVER_IP="$SERVER_IP"
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

  runtime_status TEXT DEFAULT 'stopped',
  runtime_pid TEXT,
  runtime_type TEXT DEFAULT 'node',

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS reserved_ports (
  port INTEGER PRIMARY KEY,
  allocated BOOLEAN DEFAULT false,
  app_name TEXT
);

INSERT INTO reserved_ports (port)
SELECT generate_series(3001, 3999)
ON CONFLICT DO NOTHING;

"

echo ""

echo "Initializing Api Gateway..................."
CORE_API_DIR="$EKAFY_DIR/gateway/api-gateway"


mkdir -p "$CORE_API_DIR"
cd "$CORE_API_DIR"
echo "Api Gateway in $CORE_API_DIR"
echo "Installing ....http-proxy-middleware"
npm init -y
npm install express http-proxy-middleware
echo ""

echo "Writing ....Gateway Server in $CORE_API_DIR "
cat > "$CORE_API_DIR/server.js" <<'EOF'

const fs = require('fs');
const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const { Client } = require('pg');

const app = express();

/* =========================
   LOAD ENV FILE (NO HARD CODE)
========================= */
function loadEnv(filePath) {
  const env = fs.readFileSync(filePath, 'utf-8');

  env.split('\n').forEach(line => {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) return;

    const index = trimmed.indexOf('=');
    if (index === -1) return;

    const key = trimmed.substring(0, index).trim();
    const value = trimmed.substring(index + 1).trim();

    process.env[key] = value;
  });
}

loadEnv('/srv/core/registry-db.env');

/* =========================
   POSTGRES CONNECTION
========================= */
const client = new Client({
  user: process.env.DB_USER,
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT || 5432,
});

/* =========================
   LOAD ROUTES DYNAMICALLY
========================= */
async function loadRoutes() {
  try {
    await client.connect();

    const res = await client.query(\`
      SELECT name, api_port
      FROM apps
      WHERE has_api = true
    \`);

    console.log('🚀 Loading Ekafy App Routes...');

    res.rows.forEach(appData => {
      console.log(\`📦 /${appData.name} → http://localhost:${appData.api_port}\`);

      app.use(\`/${appData.name}\`, createProxyMiddleware({
        target: \`http://localhost:\${appData.api_port}\`,
        changeOrigin: true,
      }));
    });

  } catch (err) {
    console.error('❌ Gateway DB Error:', err.message);
  }
}

/* =========================
   INIT
========================= */
loadRoutes();

/* =========================
   HEALTH CHECK
========================= */
app.get('/', (req, res) => {
  res.send('🚀 Ekafy Gateway Running');
});

app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    time: new Date().toISOString()
  });
});

/* =========================
   START SERVER
========================= */
const PORT = 3000;

app.listen(PORT, () => {
  console.log(`🚀 Ekafy API Gateway running on port \${PORT}`);
 
});
EOF
echo "Api Gateway Scripted ....."

# running api gateway-server
SERVER_FILE="$CORE_API_DIR/server.js"

# Safety check
if [[ ! -f "$SERVER_FILE" ]]; then
    echo "❌ Gateway server not found: $SERVER_FILE"
    
fi

# pm2 stop all
# echo "Stopped all PM2 "
pm2 start "$CORE_API_DIR/server.js" --name ekafy-gateway
echo "Started Ekafy-gateway in $CORE_API_DIR/server.js"
pm2 save
echo "PM2 service registered for Gateway Server.....  "

# nginx site configurations for api-gateway

echo ""
echo "🌐 Configuring Nginx for Ekafy Gateway..."
NGINX_CONF="/etc/nginx/sites-available/ekafy-gateway"
rm -f "$NGINX_CONF"



cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:3000;

        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;

        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

echo "🌐 Enabling nginx site for api-gateway..."
ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/ekafy-gateway
echo ""

echo "🧹 Removing default nginx site..."
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/inactive
echo ""

echo "🧪 Testing nginx config..."
nginx -t || { echo "❌ Nginx config failed"; exit 1; }

echo "🔄 Reloading nginx..."
sudo systemctl reload nginx
echo ""
sudo systemctl status nginx --no-pager
echo ""
echo "Testing localhost connection ..."
curl http://localhost
echo ""
echo "Checking port : 3000....."
sudo ss -tuln | grep 3000
echo ""
echo "checking Running Services ....."
sudo pm2 list








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