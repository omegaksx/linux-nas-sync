# linux-nas-sync

Hourly one-way backup from Ubuntu Linux to a UGREEN NASync DH2300 NAS over the rsync daemon protocol (port 873). No SSH required — authenticates with a username and password.

## Features

- Versioned backups — deleted or overwritten files are moved to a dated folder on the NAS instead of being permanently removed
- Silently skips a run if the NAS is unreachable (e.g. laptop off the home network)
- Single config file for all directory pairs and settings
- Setup script handles everything on a fresh machine: dependency check, password file, connection test, cron job, and first run

## Prerequisites

On the **DH2300 admin panel**:
1. Enable the rsync service (usually under *Backup Services* or *File Services*)
2. Create a user (e.g. `rsync_user`) with a password and write access to the target shared folder
3. Note the **module name** — it is the shared folder name as it appears in the rsync service settings

On the **Linux client**:
- Ubuntu (or any Debian-based distro)
- `rsync` (installed automatically by `setup.sh` if missing)

## Quick start

```bash
# 1. Clone
git clone https://github.com/omegaksx/linux-nas-sync.git
cd linux-nas-sync

# 2. Edit the config
nano nas-backup.conf

# 3. Run setup (prompts once for the NAS rsync password)
bash setup.sh
```

## Configuration

All settings live in `nas-backup.conf`:

| Variable | Description |
|---|---|
| `NAS_HOST` | NAS IP address or hostname |
| `NAS_USER` | rsync username configured on the NAS |
| `NAS_PORT` | rsync daemon port (default: `873`) |
| `PASSWORD_FILE` | Path to the local password file (default: `~/.rsync-password`) |
| `CRON_SCHEDULE` | How often to run in cron format (default: `0 * * * *` — hourly) |
| `LOG_FILE` | Path to the log file (default: `~/.local/log/nas-backup.log`) |
| `SYNC_DIRS` | Array of `local_path:module/subpath` pairs (see below) |

### Directory pairs

```bash
SYNC_DIRS=(
    "/home/cristian/Documents:backup/documents"
    "/home/cristian/Pictures:backup/pictures"
)
```

Format: `"/local/absolute/path:module/subpath"`

- The **local path** is an absolute path on the Linux machine
- The **NAS path** is `<module>/<subdirectory>` where `module` is the shared folder name from the rsync service settings on the NAS

### Versioned backups

When a file is deleted or overwritten on the Linux side, the previous copy is preserved on the NAS under `.versions/`:

```
/volume1/backup/documents/          ← live mirror
/volume1/backup/.versions/
  └── documents/
      ├── 2026-06-13_1400/          ← files changed/deleted that hour
      └── 2026-06-13_0200/
```

## Day-to-day usage

```bash
# Run a backup manually
bash nas-backup.sh

# Watch the log
tail -f ~/.local/log/nas-backup.log

# Check the cron job
crontab -l

# Edit directories
nano nas-backup.conf
```

## Re-running setup on a new machine

`setup.sh` is fully idempotent — safe to re-run:

```bash
bash setup.sh
```

It will skip steps that are already done (password file exists, rsync already installed) and re-install the cron job.
