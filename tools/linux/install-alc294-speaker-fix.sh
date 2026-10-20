#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
sudo install -m 0755 "$repo_dir/tools/linux/alc294-speaker-fix.sh" /usr/local/bin/alc294-speaker-fix
sudo install -m 0644 "$repo_dir/tools/linux/alc294-speaker-fix.service" /etc/systemd/system/alc294-speaker-fix.service
sudo install -m 0644 "$repo_dir/tools/linux/alc294-speaker-fix.timer" /etc/systemd/system/alc294-speaker-fix.timer
sudo systemctl daemon-reload
sudo systemctl disable --now alc294-speaker-fix.service 2>/dev/null || true
sudo systemctl enable --now alc294-speaker-fix.timer
sudo systemctl --no-pager --full status alc294-speaker-fix.timer
