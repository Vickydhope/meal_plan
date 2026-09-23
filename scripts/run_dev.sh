#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."

if ! pgrep -f "supabase functions serve" > /dev/null; then
  echo "Starting edge functions in the background (log: /tmp/supabase_functions_serve.log)..."
  nohup supabase functions serve --env-file supabase/functions/.env \
    > /tmp/supabase_functions_serve.log 2>&1 &
  disown
fi

LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || true)"

flutter run --flavor dev --dart-define-from-file=dart_defines/dev.json \
  ${LAN_IP:+--dart-define=SUPABASE_LOCAL_HOST=$LAN_IP} "$@"
