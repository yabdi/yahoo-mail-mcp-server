# Fork notes — yabdi/yahoo-mail-mcp-server

Fork of [`jtokib/yahoo-mail-mcp-server`](https://github.com/jtokib/yahoo-mail-mcp-server).
Upstream is effectively dormant: last push **2026-03-28**, with a dozen PRs
open since February. This fork therefore carries upstream fixes directly,
after verifying them, instead of waiting for merges.

Used in two places:

- **fiirso.app gateway** — one child per user, `YAHOO_EMAIL` /
  `YAHOO_APP_PASSWORD` injected, stdio only (`fiirso-cloud/collect.sh` bakes
  this repo into the image, so a change here ships only on redeploy).
- **laptop** — same build, credentials from `.env`.

## Adopted from upstream PRs

| PR | What | Why adopted | Verified |
|----|------|-------------|----------|
| [#20](https://github.com/jtokib/yahoo-mail-mcp-server/pull/20) (aniansh19019) | `size: true` so `size` is real, not 0; UID batch fetch passes an array (a comma-joined string made node-imap `parseInt` the first UID only); raw `Buffer` + `simpleParser` (charset, empty bodies); async parse awaited before formatting; UTF-8 header decode; `offset >= total` returns an empty page instead of the first message; `BEFORE` advanced one day so `dateFrom`/`dateTo` is inclusive on both ends | Real data bugs on every read path | Live on `yabdi@yahoo.com`: sizes non-zero (47039/5587/45684), body present, same-day search returns 10, offset 20000 returns `emails: []` |
| [#22](https://github.com/jtokib/yahoo-mail-mcp-server/pull/22) (yabdi) | MIT `LICENSE` (package.json declared MIT, no file) | Trivial, correct | — |
| [#11](https://github.com/jtokib/yahoo-mail-mcp-server/pull/11) (c-andrew-pfeiffer) | `dotenv.config({ quiet: true })` — v17 prints its banner to **stdout**, which is the JSON-RPC channel in stdio mode | Without it a line-delimited JSON client rejects the first line | No banner with or without injected creds; handshake clean |

The #11 idea is applied with an explicit `path` to this file's directory
(upstream's patch kept dotenv's cwd lookup, which is wrong when an MCP client
spawns the server elsewhere), and keeps the fork's skip-when-creds-injected
guard (`662d564`) for per-user children.

## Deliberately not adopted

- **#19** (km90001) — not a bug fix: a ~1,500-line v3.1.0 feature release
  (SMTP send/forward/reply, attachment save, 17 tools). Out of scope; sending
  stays in `yahoo_send.py` / SMTP.
- **#12** (marcoracer) — OAuth/SSE hardening (crypto tokens, redirect
  allowlist, token TTLs). Good fixes, but only the HTTP transport is affected
  and this fork runs **stdio only**; adopting it would add an untested code
  path. Revisit if HTTP mode is ever enabled.
- **#16** (Node 20) and the dependabot PRs (#3–#10) — superseded: the fork is
  on Node 22+/24 and its lockfile audits clean.

## Local-only changes

- `fix(env)`: skip `.env` entirely when `YAHOO_EMAIL` + `YAHOO_APP_PASSWORD`
  are injected (per-user children; dotenv would still read other settings).
- `fix(stdio)`: explicit `.env` path + `quiet: true`.
- `chore(deps)`: lockfile refreshed to `npm audit` 0 (sdk 1.32.2, zod 4.6.7,
  imap 0.8.17 — `npm update` must not be used blindly, it pulls newly flagged
  `imap` 0.8.18+).
- `Add audit-gated upstream sync pipeline`, `Add stdio launcher script` —
  fork maintenance tooling.

## Upstream PRs opened from this fork

- **#21** (lockfile) — **closed 2026-11-12** as superseded by #24, which brings
  the SDK to 1.32.2; #21 pinned 1.30.0, no longer clearing current advisories.
- **#22** (LICENSE) — still open; the file is already here.

Do not open a new PR for the local-only changes: they exist because Fiirso runs
one child per user, which is not upstream's deployment model.
