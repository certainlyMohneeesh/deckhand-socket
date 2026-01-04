#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIDFILE="$SCRIPT_DIR/server.pid"

# If pidfile exists, try to stop that process
if [ -f "$PIDFILE" ]; then
  PID=$(cat "$PIDFILE")
  if kill -0 "$PID" > /dev/null 2>&1; then
    echo "Stopping process $PID from pidfile..."
    kill "$PID"
    # wait for graceful shutdown
    for i in {1..10}; do
      if kill -0 "$PID" > /dev/null 2>&1; then
        sleep 0.5
      else
        break
      fi
    done
    if kill -0 "$PID" > /dev/null 2>&1; then
      echo "Force killing $PID"
      kill -9 "$PID" || true
    fi
  else
    echo "Process $PID not running. Removing stale pidfile."
  fi
  rm -f "$PIDFILE"
  echo "Stopped."
  exit 0
fi

# If no pidfile, try to find a listener on port 3001 and stop it (best-effort)
LISTENER_PID=$(lsof -t -i :3001 -sTCP:LISTEN || true)
if [ -n "$LISTENER_PID" ]; then
  echo "Found process $LISTENER_PID listening on port 3001. Attempting to stop..."
  kill $LISTENER_PID || true
  # wait
  for i in {1..10}; do
    if lsof -t -i :3001 -sTCP:LISTEN > /dev/null 2>&1; then
      sleep 0.5
    else
      break
    fi
  done
  if lsof -t -i :3001 -sTCP:LISTEN > /dev/null 2>&1; then
    echo "Force killing $LISTENER_PID"
    kill -9 $LISTENER_PID || true
  fi
  echo "Stopped process $LISTENER_PID"
  exit 0
fi

echo "No socket server pidfile or listener found on port 3001. Nothing to stop."
exit 0
