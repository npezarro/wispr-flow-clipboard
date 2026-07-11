# progress.md

<!-- Append-only. Newest entries at the bottom. -->

## 2026-07-10
- Initial repo: `wispr-clip-watch.sh` (watcher), `com.wispr-flow.clipboard.plist` (LaunchAgent template), `install.sh`, `uninstall.sh`, `README.md`, `LICENSE` (MIT). Commit: initial "Wispr Flow to macOS clipboard watcher".
- Watcher reverse-engineered from Flow's `flow.sqlite` `History` table (`formattedText`, `status`, `numWords`, `timestamp`).
- Fix 1: read via a normal query-only connection instead of `mode=ro` to avoid stale WAL snapshots while Flow writes.
- Fix 2: re-assert the clipboard for ~1.2s after copying to beat Flow's post-paste clipboard restore.
- Published public: https://github.com/npezarro/wispr-flow-clipboard (commit re-authored to GitHub noreply email due to account email-privacy protection).
- Added `context.md`, `progress.md`, and `docs/2026-07-10-closeout.md` (deep closeout).
