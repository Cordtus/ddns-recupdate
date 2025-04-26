# Dynamic Cloudflare DNS Updater

Never use a clunky DDNS service again.  
Lightweight script to fetch, update, and sync your Cloudflare DNS records automatically to your current IPv4 address.

---

## Setup

```bash
# Download or clone the script
# Make it executable
chmod +x $HOME/scripts/dns-update.sh
```

---

## Usage

### Manual (interactive zone/record selection)

```bash
bash $HOME/scripts/dns-update.sh your@email.com your_api_token
```

- You will be prompted to select which zones to operate on.
- Only selected zones/records will be updated.

### Automatic (all zones and records)

```bash
bash $HOME/scripts/dns-update.sh your@email.com your_api_token --auto
```

- Automatically fetches and updates **all A records** across **all zones**.
- No user input required.

---

## Cronjob Example

Edit your crontab:

```bash
crontab -e
```

Add this line to your crontab to automate this task to run every 30 minutes

```bash
*/30 * * * * /home/<USER>/scripts/dns-update.sh your@email.com your_api_token --auto
```

Replace `<USER>` with your actual username.

---

## Logs

- Logs are saved to: `./logs/log.json`
- Each action (update or no change) is timestamped and recorded.
- Errors are recorded with full HTTP response codes if update fails.

---

# ✅ Done
