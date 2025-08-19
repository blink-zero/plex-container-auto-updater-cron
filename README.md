# 📦 Plex Docker Auto-Updater (with Discord Notifications)

A small Bash script that checks for updates to your Plex Docker container, restarts it **only when the image actually changed**, and posts a status message to a Discord channel. It also logs to syslog.

---

## ✨ Features

- **Smart update detection** using Docker image IDs (no unnecessary restarts)
- **Conditional restart** of the Plex container when an update is pulled
- **Version reporting**: reads the installed Plex version from inside the container
- **Discord notifications** (plain text) for both update and no-update cases
- **Timestamp + hostname** included in messages
- **`.env` support** for secrets and service name
- **Logs to syslog** (and optional file via cron redirection)

---

## 📂 File Layout

```
/opt/stacks/plex/
├── docker-compose.yml
├── update_plex.sh         # This script
└── .env                   # Secrets/config (WEBHOOK_URL, SERVICE_NAME)
```

---

## 🧩 Requirements

- Docker + **Docker Compose v2** (`docker compose …`)
- Bash, `curl`, and `logger`
- A Discord Webhook URL
- Plex container based on a Debian/Ubuntu image (for `dpkg-query`), e.g. `plexinc/pms-docker`

---

## ⚙️ Configuration

Create `/opt/stacks/plex/.env`:

```env
WEBHOOK_URL=https://discord.com/api/webhooks/your_webhook_here
SERVICE_NAME=plex
```

Recommended permissions:

```bash
chmod 600 /opt/stacks/plex/.env
```

---

## 🚀 Install

1. Place the script at:

   ```
   /opt/stacks/plex/update_plex.sh
   ```

2. Make it executable:

   ```bash
   chmod +x /opt/stacks/plex/update_plex.sh
   ```

3. (Optional) Test run:

   ```bash
   /opt/stacks/plex/update_plex.sh
   ```

---

## ⏲️ Schedule with Cron

Run every Sunday at 3:00 AM and append output to a log file:

```bash
crontab -e
```

Add:

```cron
0 3 * * SUN /opt/stacks/plex/update_plex.sh >> /var/log/plex_update.log 2>&1
```

---

## 🔍 How It Works (Step-by-Step)

1. Reads config from `.env` (`WEBHOOK_URL`, `SERVICE_NAME`).
2. Captures the **current image ID** for the container.
3. Pulls the **latest image** for the service (`docker compose pull SERVICE_NAME`).
4. Captures the **new image ID** (from the running container ID).
5. If image IDs differ:
   - Brings the service down and back up (`docker compose down/up -d SERVICE_NAME`).
   - Waits briefly, then reads the **new installed Plex version** from inside the container using:
     ```
     dpkg-query -W -f='${Version}' plexmediaserver
     ```
   - Sends a Discord message: **From: old → new**.
6. If image IDs are the same:
   - Reads the **current installed version** and sends a “No update” Discord message.
7. Logs the same message to **syslog**.

If version retrieval fails (container not running or `dpkg-query` missing), the script reports:
```
Unknown (could not retrieve)
```

---

## 🖼️ Example Discord Messages

**When updated:**
```
✅ [my-host] Plex was updated and restarted.
📦 From: 1.40.2.8395-c67dce28e → 1.40.3.8555-abcdef123
🕒 Checked at: 2025-08-19 03:00:00
```

**When no update available:**
```
ℹ️ [my-host] No Plex update available.
📦 Current Version: 1.40.3.8555-abcdef123
🕒 Checked at: 2025-08-19 03:00:00
```

---

## 🔎 Troubleshooting

- **Version shows “Unknown”:** Ensure the container is running and based on Debian/Ubuntu (so `dpkg-query` exists). For other bases, adjust the version command.
- **No restart after updates:** Confirm `SERVICE_NAME` in `.env` matches the Compose service/container name.
- **Compose v1 vs v2:** The script uses `docker compose …` (v2). If you only have v1 (`docker-compose`), update your Docker or adapt the commands.
