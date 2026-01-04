#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/stop-server.sh"
# small pause to allow port to free
sleep 0.5
"$SCRIPT_DIR/start-server.sh"
