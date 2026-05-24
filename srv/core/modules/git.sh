#!/bin/bash

# -------------------------------
# Ekafy Git Sync Engine
# -------------------------------

EKAFY_DIR="/srv/core"

# -------------------------------
# Push APP to GitHub
# -------------------------------
function git_push_app() {

    APP="$1"
    APP_PATH="$EKAFY_DIR/apps/$APP"

    if [[ ! -d "$APP_PATH" ]]; then
        echo "❌ App not found"
        return 1
    fi

    cd "$APP_PATH" || return 1

    echo "📦 Syncing app: $APP"

    # check git repo
    if [[ ! -d ".git" ]]; then
        echo "❌ No git repo found in app"
        return 1
    fi

    git add .

    read -p "Commit message: " MSG
    MSG=${MSG:-"ekafy auto sync"}

    git commit -m "$MSG"

    echo "🚀 Pushing to GitHub..."
    git push origin main || {
        echo "❌ Push failed"
        return 1
    }

    echo "✅ App synced successfully"
}

# -------------------------------
# Push ENGINE to GitHub
# -------------------------------
function git_push_engine() {
	echo "..Ekafy engine pushing to main branch"

    cd "$EKAFY_DIR" || return 1

    echo "📦 Syncing Ekafy Engine..."

    if [[ ! -d ".git" ]]; then
        echo "❌ Engine is not a git repo"
        return 1
    fi

    git add .

    read -p "Commit message: " MSG
    MSG=${MSG:-"ekafy engine sync"}

    git commit -m "$MSG"

    echo "🚀 Pushing engine..."
    git push origin main || {
        echo "❌ Push failed"
        return 1
    }

    echo "✅ Engine synced successfully"
}

# -------------------------------
# Simple dispatcher
# -------------------------------
function git_dispatch() {

    TYPE="$1"
    NAME="$2"

    case "$TYPE" in
        app)
            git_push_app "$NAME"
            ;;
        engine)
            git_push_engine
            ;;
        *)
            echo "Usage:"
            echo "ekafy git app <name>"
            echo "ekafy git engine"
            ;;
    esac
}