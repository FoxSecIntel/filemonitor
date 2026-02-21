# filemonitor

Lightweight file integrity monitor for Linux systems.

It watches selected files, stores baseline hashes, and alerts when file contents change.

## Features

- SHA-256 hashing (no MD5)
- Safe state storage in a dedicated directory
- Optional email alerts
- Log file output
- One-shot mode for cron/automation
- Init-only mode to create baseline

## Usage

```bash
chmod +x filemonitor.sh

# Initialize baseline only
./filemonitor.sh --init

# Run a single check pass
./filemonitor.sh --once

# Run continuously (default every 60s)
./filemonitor.sh

# Custom files + interval + log + state dir
./filemonitor.sh -f /etc/passwd,/etc/hosts -i 30 -l /var/log/file-monitor.log -s /var/lib/filemonitor

# Enable email alerts (requires local mail command setup)
./filemonitor.sh -e you@example.com
```

## Options

- `-f` comma-separated files to monitor
- `-i` check interval in seconds
- `-e` email recipient (optional)
- `-l` log file path
- `-s` state directory for hash files
- `--once` run one pass and exit
- `--init` initialize baseline and exit

## systemd example

`/etc/systemd/system/filemonitor.service`

```ini
[Unit]
Description=File Integrity Monitor
After=network.target

[Service]
Type=simple
ExecStart=/path/to/filemonitor.sh -f /etc/passwd,/etc/hosts -i 60 -l /var/log/file-monitor.log -s /var/lib/filemonitor
Restart=always
User=root

[Install]
WantedBy=multi-user.target
```

Then:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now filemonitor.service
sudo systemctl status filemonitor.service
```

## Security notes

- Use only on systems you own or are authorized to monitor.
- Prefer minimal monitored file scope to reduce noise.
- Protect state/log paths from unauthorized write access.
