#!/bin/bash
# Nightly database dump. Schedule with cron, e.g.:
#   15 3 * * * /opt/re5-crm/scripts/backup.sh >> /var/log/re5-backup.log 2>&1
set -euo pipefail

cd "$(dirname "$0")/.."
keep_days=$(grep -E '^BACKUP_KEEP_DAYS=' .env | cut -d= -f2 || true)

backup_dir=/opt/re5-crm-backups
mkdir -p "$backup_dir"
file="$backup_dir/re5-crm-$(date +%Y%m%d-%H%M%S).sql.gz"

docker compose exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' | gzip > "$file.tmp"
mv "$file.tmp" "$file"

find "$backup_dir" -name 're5-crm-*.sql.gz' -mtime +"${keep_days:-14}" -delete

echo "$(date -Is) backup written: $file"
