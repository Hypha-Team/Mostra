#!/usr/bin/env bash
# Runs supabase/migrations + supabase/tests (pgTAP) against a throwaway local Postgres,
# with scripts/db/auth-stub.sql standing in for Supabase's auth schema.
# Needs: postgres server binaries (initdb, pg_ctl), pgTAP, pg_prove.
# Prefer `supabase db start && supabase test db` when Docker is available (that is what CI does).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PGBIN="${PGBIN:-$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)}"
TMP="$(mktemp -d)"
PORT="${PGPORT_TEST:-55432}"
export PGHOST="$TMP" PGPORT="$PORT" PGUSER=postgres PGDATABASE=postgres

cleanup() { "$PGBIN/pg_ctl" -D "$TMP/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$TMP"; }
trap cleanup EXIT

RUNAS=()
if [ "$(id -u)" = "0" ]; then chown -R postgres "$TMP"; RUNAS=(runuser -u postgres --); fi

"${RUNAS[@]}" "$PGBIN/initdb" -D "$TMP/data" -U postgres -A trust >/dev/null
"${RUNAS[@]}" "$PGBIN/pg_ctl" -D "$TMP/data" -o "-k $TMP -p $PORT -c listen_addresses=''" -l "$TMP/log" start -w >/dev/null

psql -q -v ON_ERROR_STOP=1 -f "$ROOT/scripts/db/auth-stub.sql"
psql -q -v ON_ERROR_STOP=1 -c "create extension if not exists pgtap with schema extensions;"
for f in "$ROOT"/supabase/migrations/*.sql; do
  echo "migrate: $(basename "$f")"
  psql -q -v ON_ERROR_STOP=1 -f "$f"
done
if [ "${WITH_SEED:-0}" = "1" ]; then
  echo "seed: demo.sql"
  psql -q -v ON_ERROR_STOP=1 -f "$ROOT/supabase/seed/demo.sql"
fi
psql -q -c "alter database postgres set search_path = public, extensions;"
pg_prove --ext .sql -r "$ROOT/supabase/tests"
