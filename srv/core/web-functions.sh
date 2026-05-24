web_dispatch() {
    case "$2" in
        install) web_install "$1" ;;
        remove) web_remove "$1" ;;
        status) web_status "$1" ;;
    esac
}

web_install() {

    APP="$1"

    cat > /etc/nginx/sites-available/$APP <<EOF
server {
    listen 80;
    server_name $APP.local;

    location / {
        proxy_pass http://localhost:3000;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/$APP /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
}

web_remove() {
    rm -f /etc/nginx/sites-enabled/$1
    rm -f /etc/nginx/sites-available/$1
    systemctl reload nginx
}

web_status() {
    [[ -f /etc/nginx/sites-enabled/$1 ]] && echo "ON" || echo "OFF"
}