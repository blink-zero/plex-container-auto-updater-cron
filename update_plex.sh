#!/bin/bash
# =============================================================================
# Plex Docker Auto-Updater
# =============================================================================
# Checks for a new Plex image, recreates the container if updated,
# and sends status notifications to Discord via webhook.
#
# Requirements:
#   - .env file in the same directory with SERVICE_NAME and WEBHOOK_URL
#   - Docker Compose stack at STACK_DIR
#   - curl, docker, docker compose
#
# Usage:
#   ./update_plex.sh          (run manually)
#   Add to crontab for scheduled checks
# =============================================================================

set -euo pipefail

# Ensure PATH includes standard locations for cron compatibility
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

# --- Configuration -----------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
STACK_DIR="/opt/stacks/plex"
HOSTNAME=$(hostname)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
STARTUP_WAIT=15   # seconds to wait after container recreation

# --- Load .env ---------------------------------------------------------------
if [ ! -f "$ENV_FILE" ]; then
    logger "[Plex Updater] [$HOSTNAME] .env file not found at $ENV_FILE"
    echo "ERROR: .env file not found at $ENV_FILE" >&2
    exit 1
fi

source "$ENV_FILE"

# Validate required variables
if [ -z "${SERVICE_NAME:-}" ]; then
    logger "[Plex Updater] [$HOSTNAME] SERVICE_NAME is not set in .env"
    echo "ERROR: SERVICE_NAME is not set in .env" >&2
    exit 1
fi

if [ -z "${WEBHOOK_URL:-}" ]; then
    logger "[Plex Updater] [$HOSTNAME] WEBHOOK_URL is not set in .env"
    echo "ERROR: WEBHOOK_URL is not set in .env" >&2
    exit 1
fi

# --- Helper Functions --------------------------------------------------------

# Send a message to Discord and syslog
notify() {
    local message="$1"
    logger "[Plex Updater] $message"

    # Use echo -e to convert \n to actual newlines, then jq for safe JSON encoding
    local formatted
    formatted=$(echo -e "$message")
    local payload
    payload=$(jq -n --arg content "$formatted" '{"username": "Plex Updater", "content": $content}')

    if ! curl -sf -H "Content-Type: application/json" \
         -X POST \
         -d "$payload" \
         "$WEBHOOK_URL" > /dev/null 2>&1; then
        logger "[Plex Updater] [$HOSTNAME] WARNING: Failed to send Discord notification"
    fi
}

# Get the Plex version from inside a running container
get_plex_version() {
    docker exec "$SERVICE_NAME" \
        dpkg-query -W -f='${Version}' plexmediaserver 2>/dev/null || echo "Unknown"
}

# --- Main Logic --------------------------------------------------------------

# Enter stack directory
cd "$STACK_DIR" || {
    notify "❌ [$HOSTNAME] Failed to enter stack directory: $STACK_DIR\n🕒 $TIMESTAMP"
    exit 1
}

# Ensure the container is currently running
if ! docker ps --format '{{.Names}}' | grep -q "^${SERVICE_NAME}$"; then
    notify "⚠️ [$HOSTNAME] Container '$SERVICE_NAME' is not running. Attempting to start...\n🕒 $TIMESTAMP"
    docker compose up -d "$SERVICE_NAME"
    sleep "$STARTUP_WAIT"
fi

# Get the image name from the running container's own config
# This avoids using 'docker compose config' which fails under cron
IMAGE_NAME=$(docker inspect --format='{{.Config.Image}}' "$SERVICE_NAME" 2>/dev/null)

if [ -z "$IMAGE_NAME" ]; then
    notify "❌ [$HOSTNAME] Could not determine image name from container.\n🕒 $TIMESTAMP"
    exit 1
fi

# Capture current state before pull
CURRENT_VERSION=$(get_plex_version)
OLD_IMAGE_ID=$(docker inspect --format='{{.Id}}' "$IMAGE_NAME" 2>/dev/null)

if [ -z "$OLD_IMAGE_ID" ]; then
    notify "❌ [$HOSTNAME] Could not determine current image ID.\n🕒 $TIMESTAMP"
    exit 1
fi

# Pull the latest image
if ! docker compose pull "$SERVICE_NAME"; then
    notify "❌ [$HOSTNAME] Failed to pull latest Plex image.\n📦 Current: $CURRENT_VERSION\n🕒 $TIMESTAMP"
    exit 1
fi

# Get the image ID AFTER pull — same image name, now points to the new layer
NEW_IMAGE_ID=$(docker inspect --format='{{.Id}}' "$IMAGE_NAME" 2>/dev/null)

if [ -z "$NEW_IMAGE_ID" ]; then
    notify "❌ [$HOSTNAME] Could not determine new image ID after pull.\n🕒 $TIMESTAMP"
    exit 1
fi

if [ "$OLD_IMAGE_ID" != "$NEW_IMAGE_ID" ]; then
    # --- Update detected — recreate only this service ------------------------
    if ! docker compose up -d --force-recreate "$SERVICE_NAME"; then
        notify "❌ [$HOSTNAME] Failed to recreate container after image update.\n📦 Old: $CURRENT_VERSION\n🕒 $TIMESTAMP"
        exit 1
    fi

    # Wait for Plex to start up inside the container
    sleep "$STARTUP_WAIT"

    # Verify the container is running after recreation
    if ! docker ps --format '{{.Names}}' | grep -q "^${SERVICE_NAME}$"; then
        notify "❌ [$HOSTNAME] Container failed to start after update.\n📦 Old: $CURRENT_VERSION\n🕒 $TIMESTAMP"
        exit 1
    fi

    NEW_VERSION=$(get_plex_version)
    notify "✅ [$HOSTNAME] Plex updated and restarted.\n📦 $CURRENT_VERSION → $NEW_VERSION\n🕒 $TIMESTAMP"

    # Clean up the old dangling image to reclaim disk space
    docker image prune -f > /dev/null 2>&1 || true
else
    # --- No update available --------------------------------------------------
    notify "ℹ️ [$HOSTNAME] No Plex update available.\n📦 Current: $CURRENT_VERSION\n🕒 $TIMESTAMP"
fi
