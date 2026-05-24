function ekafy_registry() {

    sudo -u postgres psql -d ekafy_registry -c "
        SELECT id, name, api_port, runtime_status
        FROM apps;
    "
}