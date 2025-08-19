
# 📦 Plex Auto-Updater with Discord Notifications  

A lightweight shell script that automatically checks for updates to your [Plex Media Server](https://www.plex.tv/) Docker container, restarts it only when needed, and sends notifications to a Discord channel.  

---

## 🔧 Features  

- Automatic update checks via cron  
- Smart detection (compares Docker image IDs before restarting)  
- No downtime unless necessary  
- Discord notifications for updates *and* no-update events  
- Includes hostname + timestamp in all messages  
- Uses `.env` file for secrets (keeps webhook safe)  
- Logs to syslog and optional file log  

---

## 📸 Example Notifications  

**When Plex is updated:**  
```
✅ [media-server] Plex was updated and restarted.
📦 Version: 1.40.2.8395-c67dce28e
🕒 Checked at: 2025-08-17 03:00:00
```

**When no update is found:**  
```
ℹ️ [media-server] No Plex update available. Container was not restarted.
🕒 Checked at: 2025-08-17 03:00:00
```

---

## 📂 File Structure  

```
/opt/stacks/plex/
├── docker-compose.yml
├── update_plex.sh       # Main script
├── .env                 # Secrets (Discord webhook, container name)
└── logs/
    └── plex_update.log  # Optional cron log
```

---

## ⚙️ Requirements  

- [Docker](https://docs.docker.com/) + Docker Compose  
- Bash  
- Plex installed via `plexinc/pms-docker`  
- Cron (for scheduled runs)  
- A Discord Webhook  

---

## 🚀 Setup  

### 1. Save the Script  
Copy `update_plex.sh` into your Plex stack directory:  

```bash
/opt/stacks/plex/update_plex.sh
```

Make it executable:  

```bash
chmod +x /opt/stacks/plex/update_plex.sh
```

---

### 2. Create the `.env` File  

Inside `/opt/stacks/plex/.env`:  

```bash
WEBHOOK_URL=https://discord.com/api/webhooks/your_webhook_here
SERVICE_NAME=plex
```

Lock it down:  

```bash
chmod 600 /opt/stacks/plex/.env
```

---

### 3. Add Cron Job  

Edit your crontab:  

```bash
crontab -e
```

Add a weekly run (every Sunday, 3AM):  

```bash
0 3 * * SUN /opt/stacks/plex/update_plex.sh >> /var/log/plex_update.log 2>&1
```

---

## 🔍 How It Works  

1. Gets the container’s current image ID.  
2. Pulls the latest Plex image.  
3. Compares new image ID to old one.  
4. If different → restarts Plex + fetches version from inside container.  
5. Sends status to Discord + logs to syslog.  
6. If unchanged → logs “No update available.”  

## 💬 Contributing  

PRs, issues, and suggestions are welcome!  
Feel free to fork and adapt for your own setup.  
```  
