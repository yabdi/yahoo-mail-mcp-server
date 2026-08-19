# Credentials — single source of truth: `.env`

The Yahoo credentials (`YAHOO_EMAIL`, `YAHOO_APP_PASSWORD`) live in **one
place**: `.env` in this repo (gitignored, mode 0600). Everything else
references it:

| Component | How it gets the credentials |
|---|---|
| `.env` (repo root) | The source — `dotenv` loads it at startup |
| `scripts/run-mcp.sh` | Runs the server from the repo root so `.env` is found; sets `DOTENV_CONFIG_QUIET=true` and `TRANSPORT_MODE=stdio` |
| `~/.config/opencode/opencode.jsonc` → `mcp.yahoo-mail` | Points at `scripts/run-mcp.sh` — carries **no** credential copies |
| `~/.dsh/profiles/web/cordis.patch.yml` → `mcp-yahoo-mail` | Same — points at `scripts/run-mcp.sh` |

## Rules

- **Only edit `.env`** when the email or app password changes — the MCP
  configs never need touching (they hold no credentials).
- **Never commit the app password** — `.env` is gitignored; `git status`
  should never show it.
- Keep `.env` at mode `0600` (owner-only read).
- The app password is IMAP-scoped and revocable: regenerate at
  <https://login.yahoo.com/account/security> (requires two-step verification)
  if it leaks or looks off, then update `.env` (and nothing else).

## Deployment safety — stdio only (audit finding)

Security audit (2026-08, PASS-WITH-NOTES for local stdio): the **stdio
transport is safe and is the only supported deployment**. The SSE / OAuth
path is **dangerous by default** and must never be run without credentials:

- `app.listen(port)` binds **all interfaces** (not localhost) even though the
  log says `http://localhost:3000`, and `authenticateMCP` is a pass-through
  when `OAUTH_CLIENT_ID`/`OAUTH_CLIENT_SECRET` are unset — any LAN peer or
  website could open `/mcp/sse` and get full mailbox read/search/move/delete.
- `docker-compose.yml` forces `TRANSPORT_MODE=sse` and publishes port 3000 —
  **do not `docker-compose up`** without OAuth creds (and ideally bind
  `127.0.0.1`).
- OAuth tokens are `Math.random()`-based and never expire — fine only if you
  never use SSE at all.
- `TRANSPORT_MODE` stays `stdio` (set by `scripts/run-mcp.sh`).

## How the server is launched

- **By an agent (opencode / DSH):** the MCP configs run
  `bash scripts/run-mcp.sh`, which `cd`s to the repo root, sets
  `DOTENV_CONFIG_QUIET=true` (dotenv v17 otherwise prints an `[dotenv]`
  banner to **stdout**, which would pollute the MCP JSON-RPC stream) and
  `TRANSPORT_MODE=stdio`, then `exec node server.js`. `dotenv` loads `.env`.
- **Directly:** `node server.js` from the repo root (same effect, banner
  included unless `DOTENV_CONFIG_QUIET=true` is set).
