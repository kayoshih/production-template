# production-template

A minimal, production-ready template for running data collection services on Linux with systemd. Includes self-healing, data freshness monitoring, age-based rotation, and automated backups.

Built for solo operators who need a system that keeps running without supervision.

## What's inside

| Component | Purpose | Schedule |
|-----------|---------|----------|
| `watchdog.sh` | Monitors systemd services, restarts failed ones | every 5 min |
| `healthcheck.sh` | Checks data freshness (file age vs max) | hourly |
| `rotate.sh` | Moves old files to archive, compresses, moves to cold storage | daily 06:00 |
| `backup.sh` | Syncs code + selected data to S3 via rclone | daily 04:00 |

All scripts are config-driven. Edit `.list` files in `config/` — no code changes needed.

## Architecture

┌─────────────────────────────────────────────────────┐
│ systemd timers │
│ watchdog.timer → watchdog.service │
│ healthcheck.timer → healthcheck.service │
│ rotate.timer → rotate.service │
│ backup.timer → backup.service │
└──────────────────┬──────────────────────────────────┘
│
┌───────────┼───────────┬──────────────┐
▼ ▼ ▼ ▼
watchdog.sh healthcheck rotate.sh backup.sh
│ .sh │ │
▼ ▼ ▼ ▼
systemctl file age age-based rclone
is-active vs max tiering sync → S3

## Quick start

```bash
# 1. Copy to target location
sudo cp -r production-template /opt/production-template
cd /opt/production-template

# 2. Edit configs
nano config/services.list       # services to monitor
nano config/healthcheck.list    # data files + max age
nano config/rotate.list         # rotation tiers
nano config/backup.list         # rclone sources → destinations

# 3. Install systemd units
sudo cp systemd/*.service /etc/systemd/system/
sudo cp systemd/*.timer   /etc/systemd/system/
sudo systemctl daemon-reload

# 4. Enable timers
sudo systemctl enable --now watchdog.timer
sudo systemctl enable --now healthcheck.timer
sudo systemctl enable --now rotate.timer
sudo systemctl enable --now backup.timer

# 5. Verify
systemctl list-timers 'watchdog*' 'healthcheck*' 'rotate*' 'backup*'

Config format

config/services.list — one systemd service per line:
myapp-collector.service
myapp-aggregator.service

config/healthcheck.list — <path>|<max_age_hours>|<name>:
/data/raw/quotes/latest.csv|2|quotes_latest
/data/raw/trades/latest.csv|24|trades_daily

config/rotate.list — <path>|<live_days>|<archive_days>|<cold_days>:
/data/raw/trades|30|90|365

config/backup.list — <source_path>|<rclone_destination>:
/home/user/project/scripts|s3:my-backup/scripts
/data/raw/algopack|s3:my-backup/data/algopack

Design principles

1.Oneshot services + timers, not long-running daemons. Simpler, more robust.

2.Config-driven. Adding a new check = edit one line in .list.

3. Log rotation built in. Every script trims its own log at 5–10 MB.

4. No secrets in code. All sensitive paths via environment variables.

Logs

Log        	Location
watchdog	/var/log/watchdog.log
healthcheck	/var/log/healthcheck.log
rotate  	/var/log/rotate.log
backup  	/var/log/backup.log

Override via environment in .service files.

Requirements

1.Linux with systemd (Ubuntu 22.04+, Debian 12+, etc.)

2.bash 4+

3.rclone (for backup) — installed and configured separately

4.gzip (for rotate)

What this template does NOT do

1.Does not manage the data collection itself (bring your own services).

2.Does not handle secrets. Use environment files or a secrets manager.

3.Does not include monitoring UI. Pair with Prometheus/Grafana if needed.

License

MIT
