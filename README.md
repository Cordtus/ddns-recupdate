````markdown
# Dynamic Cloudflare DNS Updater

Never use a clunky DDNS service again. Use this clunky bash script instead.
Lightweight Bash script to fetch, update, and sync your Cloudflare **A records** to the host’s current public IPv4 address.

---

## Setup

```bash
# copy or clone the script
mkdir -p $HOME/scripts
cp dns-update.sh $HOME/scripts/

# make it executable
chmod 700 $HOME/scripts/dns-update.sh
````

> **Prerequisites**
> \* `bash` (4.x or later)
> \* `jq` (1.5+)
> \* Cloudflare **API token** with Zone → Read and DNS → Edit
>   Authenticate with `Authorization: Bearer <TOKEN>` only—do **not** send `X‑Auth‑Email`.

---

## Usage

### Manual (interactive zone/record selection)

```bash
bash $HOME/scripts/dns-update.sh your@email.com your_api_token
```

You will be prompted to pick the zones to update; only those zones’ A records are modified.

### Automatic (all zones and records)

```bash
bash $HOME/scripts/dns-update.sh your@email.com your_api_token --auto
```

Updates **every A record** across **all zones** without user input.

---

## Cronjob Example

Edit your crontab:

```bash
crontab -e
```

Run the updater every 15 minutes:

```cron
*/15 * * * * /home/<USER>/scripts/dns-update.sh your@email.com your_api_token --auto
```

Add `SHELL=/bin/bash` and a suitable `PATH=` line **above** the job if they are not already defined for your crontab.
Replace `<USER>` with your actual username.

---

## Logs

* JSON log file: `logs/log.json` (created on first run in the same directory as the script)
* Each entry records:

  * `timestamp` (UTC)
  * `zone`
  * `record`
  * `status` (`updated`, `no_change`, or `failed`)
  * `old_ip` / `new_ip` or `ip` depending on action
* Script exits non‑zero on failure; cron will mail any error output to the user.

---

```
::contentReference[oaicite:0]{index=0}
```
