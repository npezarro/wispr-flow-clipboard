# context.md

## Last Updated
2026-07-10 — Initial build: Wispr Flow → macOS clipboard watcher, published as a public repo.

## Current State
- Working end-to-end. A LaunchAgent runs `wispr-clip-watch.sh`, which polls Flow's `flow.sqlite` and copies each finalized dictation to the clipboard.
- Verified live: 5 consecutive dictations ("Apple", "Banana.", "Cherry.", "Apple.", "Banana.") were each captured in order (see `~/Library/Logs/wispr-flow-clipboard.log` on the author's machine).
- Public repo: https://github.com/npezarro/wispr-flow-clipboard
- Two live-environment bugs found and fixed during the session:
  1. Stale reads from a `mode=ro` connection while Flow writes the WAL → switched to a normal query-only connection.
  2. Flow's post-paste "restore previous clipboard" clobbering our write → added a ~1.2s re-assert window.

## Important machine-state note (author's Mac)
The **currently running** LaunchAgent on the author's Mac was installed manually during the build session under the label `com.nicholaspezarro.wispr-clipboard` (script at `~/.local/bin/wispr-clip-watch.sh`). The repo's `install.sh` uses the canonical generic label `com.wispr-flow.clipboard`. The two coexist; running `install.sh` then booting out the old label migrates the machine to the repo version. This migration was offered to the user but not yet performed.

## Open Work
- Optional: migrate the author's live service from `com.nicholaspezarro.wispr-clipboard` to the repo's `com.wispr-flow.clipboard` so the machine matches the repo (single source of truth).
- Flow's `History` schema is internal/undocumented and may change in a future Flow release; if dictations stop reaching the clipboard, re-inspect the `History` table.
- Not yet tested against non-QWERTY layouts or Flow raw/command mode in the wild (raw mode is handled in code via a stability check but not field-verified).

## Environment Notes
- **Deploy target:** local only (macOS LaunchAgent, per-user)
- **Runtime:** bash + `sqlite3` (ships with macOS) + `pbcopy`/`pbpaste`
- **Database (read-only):** Flow's `~/Library/Application Support/Wispr Flow/flow.sqlite`, `History` table
- **Service:** LaunchAgent, `RunAtLoad` + `KeepAlive`
- **Log:** `~/Library/Logs/wispr-flow-clipboard.log` (enabled via `WISPR_CLIP_LOG`)
- **Companion:** Maccy clipboard manager (installed via `brew install --cask maccy`) for history/fallback

## Active Branch
`main`

---

**Never include:** credentials, API keys, tokens, passwords, or `.env` contents.
**For change history**, see `progress.md`.
