function product_create() {

    read -p "App name: " NAME
    read -p "Repo: " REPO

    APP=$(echo "$NAME" | tr ' ' '-')
    LOCATION="/srv/core/apps/$APP"

    [[ -d "$LOCATION" ]] && { echo "Exists"; return; }

    sudo mkdir -p "$LOCATION"/{api,web,db,logs,config}

    [[ -n "$REPO" ]] && git clone "$REPO" "$LOCATION"

    sudo -u postgres psql -d ekafy_registry -c "
        INSERT INTO apps (id, name, created_at)
        VALUES (gen_random_uuid(), '$LOCATION', NOW());
    "

    echo "✅ Product created"
}

function product_list() {
    ls /srv/ekafy-server-engine/apps
}

function product_delete() {
    rm -rf "/srv/core/apps/$1"

    sudo -u postgres psql -d ekafy_registry -c "
        DELETE FROM apps WHERE name='$1';
    "
}