# wispr-flow-clipboard

Automatically push every completed [Wispr Flow](https://wisprflow.ai) dictation onto the macOS clipboard, so you can paste it anywhere — including remote-desktop sessions like **Parsec**, RDP, or VNC where Flow's normal auto-paste fails.

## The problem

Wispr Flow delivers dictation by simulating a paste (Cmd+V) into the focused field on your **local** machine. Inside a remote-desktop window (Parsec, Citrix, RDP, VDI) that breaks in two ways:

- Parsec is just a video stream of the host. Flow can't see the host's text fields, and the synthetic Cmd+V it sends gets its **Cmd modifier dropped** on the way through Parsec — so a lone `v` lands in the remote field instead of your text.
- Flow's own "copy to clipboard" paths are inconsistent, and on a normal auto-paste Flow **saves your previous clipboard and restores it afterward**, so the transcript doesn't reliably stay on the clipboard for you to paste manually.

Flow is [officially unsupported in remote-desktop environments](https://docs.wisprflow.ai/articles/7336156466-use-flow-with-remote-desktops-citrix-rdp-vdi); the clipboard is the only reliable bridge.

## The solution

Flow stores every dictation locally in a SQLite database. This tool watches that database and, the moment a dictation is finalized, copies its text to the system clipboard. You then paste normally into the remote session (a **physical** Cmd+V passes through Parsec fine). No keystroke injection, no stray `v`, and it never loses a transcript.

Pair it with a clipboard manager (e.g. [Maccy](https://maccy.app)) and every dictation is also kept in a scrollable history.

## How it works

Flow's data lives at:

```
~/Library/Application Support/Wispr Flow/flow.sqlite
```

Dictations are rows in the `History` table. The relevant columns:

| column               | meaning                                             |
| -------------------- | --------------------------------------------------- |
| `transcriptEntityId` | primary key; a row is **updated in place** as it processes |
| `asrText`            | raw speech-to-text                                  |
| `formattedText`      | final, formatted text (what Flow would paste)       |
| `status`             | `raw_transcript` → `formatted` (terminal), or `empty` |
| `numWords`           | word count (0 while empty/in-progress)              |
| `timestamp`          | dictation time                                      |

The watcher (`wispr-clip-watch.sh`) polls every ~0.5s for the newest row with `status = 'formatted'` (the terminal state) and, when it changes, copies `formattedText` to the clipboard via `pbcopy`.

Two live-environment hazards it handles:

1. **Reading a database Flow is actively writing.** A `mode=ro` connection can read a stale WAL snapshot mid-write. The watcher uses a **normal, query-only** connection (`PRAGMA query_only=ON`) which reliably sees committed rows without ever modifying Flow's data.
2. **Flow clobbering the clipboard.** When you dictate into a focused field, Flow does save-clipboard → paste → **restore-clipboard**, overwriting what the watcher just set. After copying, the watcher **re-asserts** its text for ~1.2s to win that race.

It runs as a user LaunchAgent, so it starts at login and restarts itself if it dies.

## Requirements

- macOS
- Wispr Flow installed and signed in
- `sqlite3` (ships with macOS)

## Install

```sh
git clone https://github.com/npezarro/wispr-flow-clipboard.git
cd wispr-flow-clipboard
./install.sh
```

`install.sh` copies the watcher to `~/.local/bin/`, generates the LaunchAgent at `~/Library/LaunchAgents/com.wispr-flow.clipboard.plist`, and loads it.

Test it: dictate a line in Flow, then press Cmd+V in any app. The text should appear within ~1s.

## Uninstall

```sh
./uninstall.sh
```

## Configuration

Set these as environment variables (e.g. in the LaunchAgent's `EnvironmentVariables`, or when running the script directly):

| variable              | default                                             | purpose                      |
| --------------------- | --------------------------------------------------- | ---------------------------- |
| `WISPR_CLIP_DB`       | `~/Library/Application Support/Wispr Flow/flow.sqlite` | path to Flow's database    |
| `WISPR_CLIP_INTERVAL` | `0.5`                                               | poll interval (seconds)      |
| `WISPR_CLIP_LOG`      | *(unset)*                                           | if set, append diagnostics here |

The installed LaunchAgent sets `WISPR_CLIP_LOG` to `~/Library/Logs/wispr-flow-clipboard.log`. To disable logging, remove that key from the plist and reload.

## Managing the service

```sh
# status
launchctl print gui/$(id -u)/com.wispr-flow.clipboard | grep -E 'state|pid'

# stop / start
launchctl bootout   gui/$(id -u) ~/Library/LaunchAgents/com.wispr-flow.clipboard.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.wispr-flow.clipboard.plist

# logs
tail -f ~/Library/Logs/wispr-flow-clipboard.log
```

## Recommended workflow (Parsec)

1. Dictate normally with Flow on your local Mac.
2. The transcript is now on your clipboard (and in Maccy history if installed).
3. Click into the field inside Parsec and press Cmd+V.

If a paste is ever missed, open your clipboard manager and grab the transcript from history.

## Safety

The watcher only ever **reads** Flow's database (query-only connection) and only ever **writes** to the system clipboard. It does not modify Flow's data, touch the network, or store transcripts anywhere.

## Notes

- The `History` schema is Flow's internal, undocumented storage and could change in a future Flow release. If dictations stop appearing on the clipboard, check the log and re-inspect the `History` table schema.
- Raw/command-mode dictations (`status = 'raw_transcript'`) are copied once they've been stable for a poll cycle, to avoid grabbing text mid-formatting.

## License

MIT — see [LICENSE](LICENSE).
