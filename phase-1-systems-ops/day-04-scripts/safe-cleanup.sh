#!/usr/bin/env bash
set -euo pipefail

# --- guard the input: refuse to run without a real directory ---
LOGDIR="${1:?usage: safe-cleanup.sh <log-directory>}" # empty/unset => exit with message
ARCHIVE="/tmp/archive"

# verify it's actually a directory before we touch anything destructive
if [[ ! -d "$LOGDIR" ]]; then                          # -d = "is a directory"; ! = "not"
  echo "error: '$LOGDIR' is not a directory" >&2       # >&2 = send to stderr
  exit 1
fi

mkdir -p "$ARCHIVE"                                    # ensure archive dir exists

echo "Cleaning up logs in $LOGDIR"

# --- nullglob: if a glob matches nothing, expand to NOTHING (not the literal text) ---
shopt -s nullglob

# remove .tmp files (quoted dir, glob OUTSIDE the quotes so it still expands)
rm -f "$LOGDIR"/*.tmp                                  # -f: don't error if none exist

# --- loop over files via GLOB, never via ls ---
for f in "$LOGDIR"/*.log; do                           # f = each .log file, one per iteration
  cp "$f" "$ARCHIVE/"                                  # quote the source; copy into archive
  echo "archived $(basename "$f")"                     # basename - just the filename
done

# archive them all (nullglob means this is safe even if zero .log files)
logs=("$LOGDIR"/*.log)                                  # collect matches into an array; nullglob => empty if no matches
if [[ ${#logs[@]} -gt 0 ]]; then                         # only tar if there's something
  tar czf "$ARCHIVE/logs.tar.gz" "${logs[@]}"
  echo "Done. Files archived: ${#logs[@]}"
else
  echo "Done. No .log files to archive."
fi
