#!/bin/bash

# --- Load Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

# --- Setup ---
STACK_DIR="/opt/stacks/plex"
HOSTNAME=$(hostname)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

cd "$STACK_DIR" || {
    logger "[Plex Updater] [$HOSTNAME] Failed to enter $STACK_DIR"
    exit 1
}

# --- Get current container image ID & version ---
OLD_IMAGE_ID=$(docker inspect --format='{{.Image}}' "$SERVICE_NAME" 2>/dev/null)
CURRENT_VERSION=$(docker exec "$SERVICE_NAME" bash -c "dpkg-query -W -f='\${Version}' plexmediaserver" 2>/dev/null)
[ -z "$CURRENT_VERSION" ] && CURRENT_VERSION="Unknown (could not retrieve)"

# --- Pull latest image ---
if ! docker compose pull "$SERVICE_NAME"; then
    MESSAGE="❌ [$HOSTNAME] Failed to pull latest Plex image.\n🕒 $TIMESTAMP"
    logger "[Plex Updater] $MESSAGE"
    curl -H "Content-Type: application/json" \
         -X POST \
         -d "{\"username\": \"Plex Updater\", \"content\": \"$MESSAGE\"}" \
         "$WEBHOOK_URL"
    exit 1
fi

# --- Get new image ID ---
NEW_IMAGE_ID=$(docker inspect --format='{{.Image}}' "$(docker compose ps -q "$SERVICE_NAME")" 2>/dev/null)

# --- Compare Images ---
if [ "$OLD_IMAGE_ID" != "$NEW_IMAGE_ID" ] && [ -n "$NEW_IMAGE_ID" ]; then
    # Update detected
    docker compose down "$SERVICE_NAME"
    docker compose up -d "$SERVICE_NAME"
    sleep 10

    NEW_VERSION=$(docker exec "$SERVICE_NAME" bash -c "dpkg-query -W -f='\${Version}' plexmediaserver" 2>/dev/null)
    [ -z "$NEW_VERSION" ] && NEW_VERSION="Unknown (could not retrieve)"

    MESSAGE="✅ [$HOSTNAME] Plex was updated and restarted.\n📦 From: $CURRENT_VERSION → $NEW_VERSION\n🕒 Checked at: $TIMESTAMP"
else
    # No update
    MESSAGE="ℹ️ [$HOSTNAME] No Plex update available.\n📦 Current Version: $CURRENT_VERSION\n🕒 Checked at: $TIMESTAMP"
fi

# --- Send to Discord ---
curl -H "Content-Type: application/json" \
     -X POST \
     -d "{ \"username\": \"Plex Updater\", \"content\": \"$MESSAGE\" }" \
     "$WEBHOOK_URL"

# --- Log to syslog ---
logger "[Plex Updater] $MESSAGE"
