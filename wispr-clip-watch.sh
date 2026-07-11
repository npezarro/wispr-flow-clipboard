#!/bin/bash
# Watches Wispr Flow's local transcript DB and pushes each newly-finalized
# dictation onto the macOS clipboard, so it is ready to paste (e.g. into a
# Parsec / RDP / VNC remote session where Flow's auto-paste does not work).
#
# Flow writes every dictation to the History table in flow.sqlite. A row is
# updated in place (same transcriptEntityId) as it moves through statuses;
# 'formatted' is the terminal state holding the final text. We poll and, when
# the newest finalized transcript changes, copy its text to the clipboard.
#
# Two live-environment hazards handled:
#  1. Reading a WAL DB that Flow is actively writing: we use a normal
#     query-only connection (not mode=ro), which reliably sees committed rows.
#  2. Flow's auto-paste restores the previous clipboard right after pasting,
#     clobbering what we set. We re-assert our text for a short window to win.
#
# Config via environment variables:
#   WISPR_CLIP_DB        path to flow.sqlite (default: standard install path)
#   WISPR_CLIP_INTERVAL  poll interval in seconds (default: 0.5)
#   WISPR_CLIP_LOG       if set, append diagnostic lines to this file

DB="${WISPR_CLIP_DB:-$HOME/Library/Application Support/Wispr Flow/flow.sqlite}"
INTERVAL="${WISPR_CLIP_INTERVAL:-0.5}"
LOG="${WISPR_CLIP_LOG:-}"

log() { [ -n "$LOG" ] && printf '%s %s\n' "$(date '+%H:%M:%S')" "$1" >>"$LOG"; }

# Normal connection (sees live WAL data), query-only so we never modify Flow's
# data, with a busy timeout so a momentary lock yields a retry not an error.
q() { sqlite3 -cmd ".timeout 2000" -cmd "PRAGMA query_only=ON" "$DB" "$1" 2>>"${LOG:-/dev/null}"; }

newest_meta() {
  q "SELECT transcriptEntityId || '|' || status
     FROM History
     WHERE numWords > 0 AND status IN ('formatted','raw_transcript')
     ORDER BY timestamp DESC LIMIT 1;"
}

text_for() {
  q "SELECT COALESCE(NULLIF(formattedText,''), asrText)
     FROM History WHERE transcriptEntityId = '$1';"
}

# Copy text, then defend it against Flow restoring the old clipboard after its
# auto-paste. Re-assert for ~1.2s if something overwrites it.
put_clipboard() {
  local txt="$1" k cur
  printf '%s' "$txt" | pbcopy
  for k in 1 2 3 4 5 6; do
    sleep 0.2
    cur="$(pbpaste)"
    [ "$cur" != "$txt" ] && printf '%s' "$txt" | pbcopy
  done
}

# Seed: treat whatever exists now as already-seen so we do not clobber the
# clipboard with an old transcript on startup.
last="$(q "SELECT transcriptEntityId FROM History ORDER BY timestamp DESC LIMIT 1;")"
prev_raw_id=""
log "started; DB=$DB seed_last=$last"

while true; do
  meta="$(newest_meta)"
  if [ -n "$meta" ]; then
    id="${meta%%|*}"
    status="${meta##*|}"
    if [ -n "$id" ] && [ "$id" != "$last" ]; then
      push=0
      if [ "$status" = "formatted" ]; then
        push=1
      elif [ "$status" = "raw_transcript" ] && [ "$id" = "$prev_raw_id" ]; then
        push=1
      fi
      log "new id=$id status=$status last=$last push=$push"
      if [ "$push" = 1 ]; then
        txt="$(text_for "$id")"
        if [ -n "$txt" ]; then
          put_clipboard "$txt"
          last="$id"
          log "COPIED id=$id [${txt:0:60}]"
        else
          log "empty text for id=$id, will retry"
        fi
      fi
    fi
    [ "$status" = "raw_transcript" ] && prev_raw_id="$id" || prev_raw_id=""
  fi
  sleep "$INTERVAL"
done
