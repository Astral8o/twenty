#!/bin/bash
# Gives an existing user server admin rights: the admin panel, creating
# client workspaces and impersonating users for support.
# Usage: scripts/make-admin.sh you@re5agency.com
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <email>"
  exit 1
fi

cd "$(dirname "$0")/.."

updated=$(docker compose exec -T -e EMAIL="$1" db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -qtA -v email="$EMAIL"' <<'SQL'
UPDATE core."user" SET "canAccessFullAdminPanel" = true, "canImpersonate" = true
WHERE email = :'email' RETURNING email;
SQL
)

if [ -z "$updated" ]; then
  echo "No user found with email $1. Sign up first, then rerun."
  exit 1
fi

echo "$updated is now a server admin. Log out and back in."
