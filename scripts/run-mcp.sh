#!/usr/bin/env bash
# MCP launcher for yahoo-mail-mcp-server (stdio only).
#
# Runs the server from the repo root so dotenv loads `.env` — the single
# source of truth for YAHOO_EMAIL / YAHOO_APP_PASSWORD (see scripts/README.md
# for the credential-sync rules). Agent MCP configs (opencode, DSH) point at
# this script instead of carrying their own copies of the credentials.
#
# DOTENV_CONFIG_QUIET keeps stdout a clean JSON-RPC stream: dotenv v17 prints
# an "[dotenv] injecting env" banner to stdout otherwise, which would pollute
# the MCP stdio protocol.
set -euo pipefail
cd "$(dirname "$0")/.."
export DOTENV_CONFIG_QUIET=true
export TRANSPORT_MODE=stdio
exec node server.js
