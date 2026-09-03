#!/bin/bash
# combo-entrypoint.sh — Hermes combo image entrypoint
# Runs the agent gateway (background) + the WebUI server (foreground),
# replicating the behaviour of the linkease/hermes iStore container.
set -e

# s6 helper tools live under these paths in the agent image
export PATH="/command:/package/admin/s6/command:${PATH}"

export HERMES_HOME="${HERMES_HOME:-/opt/data}"
export HERMES_WEBUI_STATE_DIR="${HERMES_WEBUI_STATE_DIR:-${HERMES_HOME}/webui}"
export HERMES_WEBUI_HOST="${HERMES_WEBUI_HOST:-0.0.0.0}"
export HERMES_WEBUI_PORT="${HERMES_WEBUI_PORT:-8787}"
export HERMES_WEBUI_AGENT_DIR="${HERMES_WEBUI_AGENT_DIR:-/workspace}"
export HERMES_WEBUI_DEFAULT_WORKSPACE="${HERMES_WEBUI_DEFAULT_WORKSPACE:-/workspace}"

mkdir -p "${HERMES_HOME}" "${HERMES_WEBUI_STATE_DIR}"

# Agent stage2 bootstrap: ownership fix, API_SERVER_KEY generation, skill sync.
# It chowns HERMES_HOME to the hermes user (uid 10000).
if [ -x /opt/hermes/docker/stage2-hook.sh ]; then
  echo "[combo] running agent stage2 bootstrap"
  /opt/hermes/docker/stage2-hook.sh || echo "[combo] stage2 reported a warning (continuing)"
fi

# Surface an auto-generated API_SERVER_KEY to the WebUI process if present.
if [ -z "${API_SERVER_KEY:-}" ] && [ -f "${HERMES_HOME}/.env" ]; then
  _key="$(grep -E '^API_SERVER_KEY=' "${HERMES_HOME}/.env" 2>/dev/null | tail -n1 | cut -d= -f2-)"
  if [ -n "${_key}" ]; then export API_SERVER_KEY="${_key}"; fi
fi

echo "[combo] starting hermes gateway (background)"
s6-setuidgid hermes hermes gateway run &
_gw=$!

echo "[combo] starting hermes-webui server (foreground) on :${HERMES_WEBUI_PORT}"
cd /opt/hermes-webui
exec s6-setuidgid hermes /opt/hermes/.venv/bin/python server.py
