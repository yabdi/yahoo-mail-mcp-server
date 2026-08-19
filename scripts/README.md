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

## Keeping the fork current — automated, audit-gated sync

`sync-upstream.sh` (weekly cron, or manual) keeps this fork in step with
upstream `jtokib/yahoo-mail-mcp-server` **without ever merging unvetted
code**:

1. Fast-forwards local `main` to the fork's `origin/main`.
2. Fetches upstream; exits early when there is nothing new.
3. **Pre-merge audit gate** — static scan of the incoming diff
   (`audit-upstream.sh --range`): code-execution primitives
   (eval/Function/child_process/exec), unexpected network hosts (allowlist:
   `imap.mail.yahoo.com`, `login.yahoo.com`, `localhost`, npm/github hosts),
   TLS-verification bypass, hardcoded credentials, base64 blobs, secrets in
   the incoming commits.
4. Stages the merge (`git merge --no-commit --no-ff`).
5. **Post-merge audit gate** on the merged tree (`audit-upstream.sh
   --worktree`): `npm install`, `npm audit` vs baseline (auto `npm audit
   fix`; fail if still above), lockfile hygiene (registry.npmjs.org only, no
   install scripts), `.env` untracked.
6. Commits the merge (including any audit-fix lockfile changes), smoke-tests
   the MCP stdio handshake, then pushes.

Any gate failure aborts **before** the merge is committed or pushed — a bad
upstream change never lands on the fork. Failures (and successes) notify via
ntfy when `~/.config/gmail-inbox-watcher/config.json` exists; otherwise they
land in `~/.local/share/yahoo-mail-mcp/sync.log`.

Tuning: `AUDIT_MAX_HIGH` (default 3 — the unfixable deepmerge-ts chain),
`AUDIT_MAX_CRITICAL` (default 0). Dry run: `./scripts/sync-upstream.sh
--dry-run`.

## How the server is launched

- **By an agent (opencode / DSH):** the MCP configs run
  `bash scripts/run-mcp.sh`, which `cd`s to the repo root, sets
  `DOTENV_CONFIG_QUIET=true` (dotenv v17 otherwise prints an `[dotenv]`
  banner to **stdout**, which would pollute the MCP JSON-RPC stream) and
  `TRANSPORT_MODE=stdio`, then `exec node server.js`. `dotenv` loads `.env`.
- **Directly:** `node server.js` from the repo root (same effect, banner
  included unless `DOTENV_CONFIG_QUIET=true` is set).
