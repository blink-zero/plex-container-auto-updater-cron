# Plex Docker Auto-Updater

A lightweight bash script that checks for Plex Media Server Docker image updates, recreates the container when a new version is available, and sends notifications to Discord.

## How It Works

1. Inspects the currently running Plex container to get the image ID
2. Pulls the latest image from the registry
3. Compares image IDs — if they differ, an update is available
4. Recreates the container using `docker compose up -d --force-recreate`
5. Sends a status notification to Discord via webhook

No update? No restart. The container is only recreated when the image actually changes.

## Requirements

- Docker with Compose plugin
- `jq` (`sudo apt install jq`)
- `curl`
- A Discord webhook URL

## Setup

1. Place `update-plex` in your Plex stack directory (e.g. `/opt/stacks/plex/`)
2. Create a `.env` file in the same directory:

```
SERVICE_NAME=plex
WEBHOOK_URL=https://discord.com/api/webhooks/your/webhook/url
```

3. Make the script executable:

```bash
chmod +x /opt/stacks/plex/update_plex.sh
```

4. Add to crontab for scheduled checks:

```bash
crontab -e
```

```
0 3 * * SUN /opt/stacks/plex/update_plex.sh >> /home/user/plex_update.log 2>&1
```

## Discord Notifications

| Status | Meaning |
|--------|---------|
| ✅ | Plex was updated and restarted |
| ℹ️ | No update available |
| ❌ | Something went wrong (pull failed, container didn't start, etc.) |
| ⚠️ | Container wasn't running, attempted to start |

## Manual Run

```bash
bash /opt/stacks/plex/update_plex.sh
```
