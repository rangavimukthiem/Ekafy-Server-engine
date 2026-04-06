#!/bin/bash

# -------------------------------
# Ekafy Engine Functions
# -------------------------------
REGISTRY_DB="ekafy_registry"
function run_psql() {
  cd /tmp || exit 1
  sudo -u postgres psql -v ON_ERROR_STOP=1 "$@"
}
function product_create() {
  echo "🚀 Ekafy – Create Product"
  echo "------------------------"

  read -p "Product name (Spaces Not Allowed) : " USER_APP_NAME
  read -p "Git repository (SSH Repo Address ex:- 'git@github.com:User/repo.git'  ): " PROD_REPO

  read -p "Enable API? (y/n): " ENABLE_API
  read -p "Enable Database (PostgreSQL)? (y/n): " ENABLE_DB
  read -p "Enable Web? (y/n): " ENABLE_WEB
  
  PROD_NAME=$(echo "$USER_APP_NAME" | tr ' ' '_')

  [[ "$ENABLE_API" == "y" ]] && HAS_API=true || HAS_API=false
  [[ "$ENABLE_DB" == "y" ]] && HAS_DB=true || HAS_DB=false
  [[ "$ENABLE_WEB" == "y" ]] && HAS_WEB=true || HAS_WEB=false

  APP_ID=$(uuidgen)
  PROD_PATH="/srv/ekafy-server-engine/apps/$PROD_NAME"
  EKAFY_PATH="/srv/ekafy-server-engine"
  REGISTRY_DB="ekafy_registry"
  

  # ---- validations ----
  if [[ -z "$PROD_NAME" ]]; then
    echo "❌ Product name is required"
    return 1
  fi

  if [[ -d "$PROD_PATH" ]]; then
    echo "❌ Product already exists"
    return 1
  fi
  
  
  
  # ---- git clone (optional) ----
if [[ -n "$PROD_REPO" ]]; then
    echo "🔗 Cloning repository..."
    if ! sudo git clone "$PROD_REPO" "$PROD_PATH"; then
        echo "⚠️ Git clone failed, proceeding with empty Project"
        # don't remove PROD_PATH
    fi
fi

  # ---- create base structure ----
sudo mkdir -p "$PROD_PATH"/{logs,config,secrets}
  
if [[ "$HAS_API" -eq true ]]; then
    sudo mkdir -p "$PROD_PATH/api"
    echo "📁 API directory created at: $PROD_PATH/api"
fi

if [[ "$HAS_WEB" -eq true ]]; then
    sudo mkdir -p "$PROD_PATH/web"
    echo "📁 WEB directory created at: $PROD_PATH/web"
fi

if [[ "$HAS_DB" -eq true ]]; then
    sudo mkdir -p "$PROD_PATH/db"
    echo "📁 DB directory created at: $PROD_PATH/db"
fi
  

 # ---- PostgreSQL provisioning ----
if [[ $HAS_DB -eq true ]]; then
  echo "🗄️  Provisioning PostgreSQL database..."

  DB_NAME="ekafy_${PROD_NAME}_db"
  DB_USER="ekafy_${PROD_NAME}_user"
  DB_PASS="$(openssl rand -hex 16)"

  # ---- Create DB user if missing ----
  sudo -u postgres psql -tc \
    "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1 || \
  sudo -u postgres psql -c \
    "CREATE USER \"${DB_USER}\" WITH ENCRYPTED PASSWORD '${DB_PASS}';" \
    || { echo "❌ Failed to create DB user"; sudo rm -rf "$PROD_PATH"; return 1; }

  # ---- Create DB if missing ----
  sudo -u postgres psql -tc \
    "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1 || \
  sudo -u postgres psql -c \
    "CREATE DATABASE \"${DB_NAME}\" OWNER \"${DB_USER}\";" \
    || { echo "❌ Failed to create database"; sudo rm -rf "$PROD_PATH"; return 1; }

  # ---- Save DB credentials ----
  echo "writing Db Config to config/db.env .."
  sudo tee "$PROD_PATH/config/db.env" > /dev/null <<EOF
DB_TYPE=postgres
DB_HOST=localhost
DB_PORT=5432
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASS}
EOF

  sudo chmod 600 "$PROD_PATH/config/db.env"
fi


  # ---- API scaffold -------------------------------------------------------------------------------------------------
  
  if [[ $HAS_API -eq true ]]; then
    sudo tee "$PROD_PATH/api/index.sh" > /dev/null <<EOF
#!/bin/bash
echo "API running for $PROD_NAME"
EOF



sudo chmod +x "$PROD_PATH/api/index.sh"
echo "Writing api Documents in /api/...."
  fi

  # ---- Web scaffold -----------------------------------------------------------------------------------------------------
  
  if [[ $HAS_WEB -eq true ]]; then
    sudo tee "$PROD_PATH/web/index.html" > /dev/null <<EOF
<h1>$PROD_NAME</h1>
<p>Powered by Ekafy Server Engine</p>
EOF
echo "Writing api Documents in /web/...."
  fi

  # ---- App config -------------------------------------------------------------------------------------------------------
  sudo tee "$PROD_PATH/config/app.env" > /dev/null <<EOF
APP_ID="$APP_ID"
APP_NAME="$PROD_NAME"
HAS_API="$HAS_API"
HAS_DB="$HAS_DB"
HAS_WEB="$HAS_WEB"
GIT_REPO="$PROD_REPO"


EOF

sudo chmod 600 "$PROD_PATH/config/app.env"
echo "Writing App configs in /configs/...."

# ---- Register app in Ekafy PostgreSQL registry ----
# Assumptions:
# REGISTRY_DB_NAME="ekafy_registry"
# Using sudo -u postgres to run psql
# Fields: id (uuid), name (text), has_api (bool), has_db (bool), has_web (bool), repo (text), db_name (text), db_user (text), api_port (int), created_at (timestamp)

API_PORT=${API_PORT:-NULL}       # Optional: leave NULL if not set
CREATED_AT=$(date +"%Y-%m-%d %H:%M:%S")



if ! run_psql -d "$REGISTRY_DB" <<EOF
BEGIN;

INSERT INTO apps (
    id, name, has_api, has_db, has_web,
    repo, db_name, db_user, api_port, created_at
) VALUES (
    '$APP_ID',
    '$PROD_NAME',
    $HAS_API,
    $HAS_DB,
    $HAS_WEB,
    $( [[ -n "$PROD_REPO" ]] && echo "'$PROD_REPO'" || echo NULL ),
    $( [[ -n "$DB_NAME"  ]] && echo "'$DB_NAME'"  || echo NULL ),
    $( [[ -n "$DB_USER"  ]] && echo "'$DB_USER'"  || echo NULL ),
    ${API_PORT:-NULL},
    '$CREATED_AT'
);

COMMIT;
EOF
then
  echo "❌ Oops! App registration failed — rolling back everything..."
  product_delete "$PROD_NAME" "yes"
  echo "🧹 Rollback completed."
  return 1
fi




 echo "App has been registered on server  App configs in /configs/...."
 
 echo "--------------------------------------------------------------Ekafy---App----Registry--------------------------------------------------------------------------------------------------"
 
run_psql -d "$REGISTRY_DB" <<EOF
SELECT *
FROM apps
WHERE name = '$PROD_NAME';

EOF
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
 

}


# ---------------------------------------------------------------------------------------------------
# List all products
# ---------------------------------------------------------------------------------------------------
function product_list() {
    APPS_DIR="/srv/ekafy-server-engine/apps"

    # Check if apps directory exists
    if [ ! -d "$APPS_DIR" ]; then
        echo "⚠️ No products found. Directory $APPS_DIR does not exist."
        return
    fi

    # List all products
    PRODUCTS=($(ls -1 "$APPS_DIR"))

    if [ ${#PRODUCTS[@]} -eq 0 ]; then
        echo "ℹ️  No products created yet."
        return
    fi

    echo "📦 Products created by Ekafy:"
    echo "-----------------------------------"
    for PROD in "${PRODUCTS[@]}"; do
        PROD_PATH="$APPS_DIR/$PROD"
        TYPE="Unknown"

        # Try to read type from .ekafy_product.env
        if [ -f "$PROD_PATH/.ekafy_product.env" ]; then
            TYPE=$(grep '^TYPE=' "$PROD_PATH/.ekafy_product.env" | cut -d'=' -f2)
        fi

        echo "• $PROD  [$TYPE]"
    done
    echo "-----------------------------------"
}
# -------------------------------
# Delete a product safely
# -------------------------------
function product_delete() {
    PROD_NAME="$1"
    COMMAND="$2"
    
    
    if  [[ $COMMAND == "yes" ]]; then
        CONFIRM="yes"
        
    else 
    	product_list
        read -p "Enter (yes) To Proceed " CONFIRM
        
        
    	
    fi 
    
    if [ -z "$PROD_NAME" ]; then
        echo "❌ Please specify the product name to delete."
        echo "Usage: ekafy product delete <product_name>"
        read -p "Product name  : " PROD_NAME
        
    fi
    

    PROD_PATH="/srv/ekafy-server-engine/apps/$PROD_NAME"

    if [ ! -d "$PROD_PATH" ]; then
        echo "⚠️ Product '$PROD_NAME' does not exist."
        return 1
    fi

    DB_NAME="ekafy_${PROD_NAME}_db"
    DB_USER="ekafy_${PROD_NAME}_user"

    echo ""
    echo "⚠️  You are about to DELETE:"
    echo "   • Product files : $PROD_PATH"
    echo "   • Database      : $DB_NAME"
    echo "   • DB User       : $DB_USER"
    echo ""


    if [ "$CONFIRM" != "yes" ]; then
        echo "❌ Deletion cancelled. Wrong confirmation"
        return 0
    fi

    echo ""
    echo "🧹 Removing product files..."
    sudo rm -rf "$PROD_PATH"

    

    echo "🗑️  Removing PostgreSQL user (if exists)..."
    
    # Terminate user sessions first
	# Terminate all active sessions
	sudo -u postgres psql -d postgres -c "
	SELECT pg_terminate_backend(pid)
	FROM pg_stat_activity
	WHERE usename = '$DB_USER';
	" 

	echo "🗑️  Removing PostgreSQL database (if exists)..."

	# Reassign owned objects (optional) or drop database first
	sudo -u postgres psql -d postgres -c "DROP DATABASE IF EXISTS \"$DB_NAME\";"

	 echo "🗑️  Removing PostgreSQL user (if exists)..."
	# Drop user safely
	sudo -u postgres psql -d postgres -c "DROP USER IF EXISTS \"$DB_USER\";"
    
    echo ""
    echo "✅ Product '$PROD_NAME' fully removed."
}

ekafy_remove() {

    EKAFY_DIR="/srv/ekafy-server-engine"
    REGISTRY_DB="ekafy_registry"
    REGISTRY_USER="ekafy_admin"

    echo "⚠️  EKAFY SERVER ENGINE UNINSTALLATION"
    echo "----------------------------------------"
    echo "This will completely remove Ekafy from this server."
    echo ""

    echo "What will be removed:"
    echo "  - Ekafy engine files"
    echo "  - Ekafy system user"
    echo "  - All app databases & DB users"
    echo "  - Ekafy registry database"
    echo ""

    echo "What will NOT be removed (optional):"
    echo "  - Applications inside $EKAFY_DIR/apps"
    echo ""

    read -rp "Type REMOVE to continue: " CONFIRM

    if [[ "$CONFIRM" != "REMOVE" ]]; then
        echo "❌ Aborted."
        return 1
    fi

    echo ""
    read -rp "Remove ALL apps as well? (y/N): " REMOVE_APPS
    read -rp "Remove PostgreSQL databases? (y/N): " REMOVE_DB

    # normalize input
    REMOVE_APPS=${REMOVE_APPS,,}
    REMOVE_DB=${REMOVE_DB,,}

    echo ""

    # --------------------------------------------------
    # 🗄️ REMOVE DATABASES (APPS + REGISTRY)
    # --------------------------------------------------
    if [[ "$REMOVE_DB" == "y" ]]; then
        echo "🗄️  Removing ALL Ekafy databases..."

        # Check if registry DB exists
        DB_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${REGISTRY_DB}'")

        if [[ "$DB_EXISTS" == "1" ]]; then

            # ---- Get all app DBs and users ----
            APP_DBS=$(sudo -u postgres psql -t -d "$REGISTRY_DB" -c "SELECT db_name FROM apps WHERE name IS NOT NULL;" | xargs)
            APP_USERS=$(sudo -u postgres psql -t -d "$REGISTRY_DB" -c "SELECT db_user FROM apps WHERE db_user IS NOT NULL;" | xargs)

            # ---- Drop app databases ----
            for DB in $APP_DBS; do
                echo "🗑️  Dropping database: $DB"

                sudo -u postgres psql -d postgres -c "
                SELECT pg_terminate_backend(pid)
                FROM pg_stat_activity
                WHERE datname = '$DB';
                " >/dev/null 2>&1

                sudo -u postgres psql -d postgres -c "DROP DATABASE IF EXISTS \"$DB\";"
            done

            # ---- Drop app users ----
            for USER in $APP_USERS; do
                echo "👤 Dropping DB user: $USER"
                sudo -u postgres psql -d postgres -c "DROP ROLE IF EXISTS \"$USER\";"
            done

            # ---- Drop registry DB ----
            echo "🗄️  Dropping registry database..."

            sudo -u postgres psql -d postgres -c "
            SELECT pg_terminate_backend(pid)
            FROM pg_stat_activity
            WHERE datname = '$REGISTRY_DB';
            " >/dev/null 2>&1

            sudo -u postgres psql -d postgres -c "DROP DATABASE IF EXISTS \"$REGISTRY_DB\";"
            sudo -u postgres psql -d postgres -c "DROP ROLE IF EXISTS \"$REGISTRY_USER\";"

        else
            echo "⚠️  Registry DB not found. Skipping DB cleanup."
        fi
    else
        echo "📦 Skipping database removal"
    fi

    # --------------------------------------------------
    # 📁 REMOVE APPLICATION FILES
    # --------------------------------------------------
    if [[ "$REMOVE_APPS" == "y" ]]; then
        echo "🔥 Removing all Ekafy applications..."
        sudo rm -rf "$EKAFY_DIR/apps"
    else
        echo "📦 Preserving applications directory"
    fi

    # --------------------------------------------------
    # 🧹 REMOVE ENGINE FILES
    # --------------------------------------------------
    echo "🧹 Removing Ekafy engine files..."
    sudo rm -rf "$EKAFY_DIR"/{logs,secrets,config,core}
    sudo rm -f "$EKAFY_DIR/.initialized"

    # --------------------------------------------------
    # 👤 REMOVE SYSTEM USER
    # --------------------------------------------------
    echo "👤 Removing Ekafy system user..."
    sudo userdel ekafy 2>/dev/null || true

    # --------------------------------------------------
    # 🧾 FINAL MESSAGE
    # --------------------------------------------------
    echo ""
    echo "✅ Ekafy has been completely removed from this server."
    echo "⚠️  Some components may remain if you chose to skip them."
}
function ekafy_registry(){

echo "--------------------------------------------------------------Ekafy---App----Registry--------------------------------------------------------------------------------------------------"
 
run_psql -d "$REGISTRY_DB" <<EOF
SELECT *
FROM apps ;

EOF
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
 

}

# function set_git(

# $GIT_REPO


# )
