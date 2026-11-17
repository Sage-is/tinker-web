#!/bin/sh
# The start check. When web mode is on but the host page is missing, upstream's
# tenkts-server logs "Tinker for the web is off" and keeps serving the library API
# (server/src/lib.rs), so a broken image would look healthy. Stop here instead.
set -eu

web="$(printf '%s' "${TENKTS_WEB:-}" | tr -d '[:space:]')"
if [ -n "$web" ] && [ "$web" != "0" ]; then
  ui="${TENKTS_WEB_UI:-ui}"
  if [ ! -f "$ui/index.html" ]; then
    echo "tinker-web: no host page at $ui/index.html, so web mode would turn itself off." >&2
    echo "tinker-web: set TENKTS_WEB_UI to the folder holding upstream's ui/." >&2
    exit 1
  fi
fi

exec "$@"
