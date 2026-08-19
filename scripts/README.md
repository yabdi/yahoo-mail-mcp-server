# Credential sync — keep these three copies in step

The Yahoo credentials (`YAHOO_EMAIL`, `YAHOO_APP_PASSWORD`) are needed in
**three** places. All three must be updated together whenever the app password
changes or is regenerated:

| # | File | Used by |
|---|---|---|
| 1 | `.env` (repo root, gitignored, mode 0600) | Direct runs: `node server.js` from this repo (`dotenv` loads it) |
| 2 | `~/.config/opencode/opencode.jsonc` → `mcp.yahoo-mail.environment` | opencode MCP launch |
| 3 | `~/.dsh/profiles/web/cordis.patch.yml` → `mcp-yahoo-mail` env block | DeepSeek Harness MCP launch |

## Rules

- **Never commit the app password** — `.env` is gitignored; the two config
  files live outside this repo, in the home dir. `git status` should never show
  `.env`.
- Keep `.env` at mode `0600` (owner-only read).
- If only one copy is updated, the other launchers silently keep using the old
  password and auth fails with `[AUTHENTICATIONFAILED]` — update all three.
- The app password is IMAP-scoped and revocable: regenerate at
  <https://login.yahoo.com/account/security> (requires two-step verification)
  if it leaks or looks off, then update all three copies above.

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
- `TRANSPORT_MODE` must stay `stdio` (the default; also set explicitly in the
  MCP configs).

## How the server is launched

The MCP configs start the server with `TRANSPORT_MODE=stdio` via
`node /home/yusuf.abdi/code/yahoo-mail-mcp-server/server.js`. The process env
from the MCP config wins over `.env` (dotenv does not override existing env
vars), so configs 2 and 3 are authoritative when launched by an agent; `.env`
only matters for direct CLI runs.
