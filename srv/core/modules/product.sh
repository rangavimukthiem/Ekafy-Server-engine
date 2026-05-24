function product_create() {

    read -p "App name: " NAME
    read -p "Repo: " REPO

    APP=$(echo "$NAME" | tr ' ' '_')
    PATH="/srv/core/apps/$APP"

    [[ -d "$PATH" ]] && { echo "Exists"; return; }

    mkdir -p "$PATH"/{api,web,db,logs,config}

    [[ -n "$REPO" ]] && git clone "$REPO" "$PATH"

    sudo -u postgres psql -d ekafy_registry -c "
        INSERT INTO apps (id, name, created_at)
        VALUES (gen_random_uuid(), '$APP', NOW());
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