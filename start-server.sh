#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIDFILE="$SCRIPT_DIR/server.pid"
LOGFILE="$SCRIPT_DIR/server.log"

if [ -f "$PIDFILE" ]; then
  PID=$(cat "$PIDFILE")
  if kill -0 "$PID" > /dev/null 2>&1; then
    echo "Socket server already running (pid $PID)"
    exit 0
  else
    echo "Stale pidfile found. Removing."
    rm -f "$PIDFILE"
  fi
fi

cd "$SCRIPT_DIR"
nohup bun run server.ts > "$LOGFILE" 2>&1 &
echo $! > "$PIDFILE"
sleep 0.5
echo "Started socket server (pid $(cat $PIDFILE)), logs: $LOGFILE" 
