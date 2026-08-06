# Day 04 — Bash I: Safe Scripting

## Security thread
**Unsafe scripts as an attack vector.** Scripts run with privileges you already
granted — often as root, often on paths and input you don't fully control (cron,
systemd services, deploy pipelines). A bash mistake isn't cosmetic; it's a
privilege aimed at the wrong target. Safe-by-construction scripting is Day 2–3
least-privilege applied to *what the script itself can do*.

**Real disaster:** the 2015 Steam-for-Linux bug — `rm -rf "$STEAMROOT/"*` with
`STEAMROOT` empty became `rm -rf "/"*`, recursively deleting everything the user
could touch, including mounted drives. One unset variable turned cleanup into a
data-destruction weapon.

## The mechanism that matters: WHEN the shell transforms text
Writing `$var` triggers, in order: (1) substitute value, (2) **word-split** on
spaces, (3) **glob-expand** `*`/`?`. Steps 2–3 are where scripts get exploited.

**Three DIFFERENT bugs, three DIFFERENT fixes — none substitutes for another:**

| Bug | Fix | Why the others miss it |
|---|---|---|
| var holds `report final.txt` (spaces) → splits into 2 args | **quoting** `"$var"` | `set -u` — var IS set |
| var holds `*.txt` (wildcard) → globs into filenames | **quoting** `"$var"` | `set -u` — var IS set |
| var **unset** → collapses to empty, path breaks (`rm -rf /build`) | **`set -u`** | quoting — empty stays empty |
| var set but **empty** (`X=""`) | **`${X:?msg}`** guard | BOTH `set -u` and quoting miss it |

One-liner: *Quoting protects what's IN a variable; `set -u` protects against a
variable being unset; `${var:?}` protects against empty for any reason. Safe
scripts use all three.*

## The safety harness: `set -euo pipefail`
- **`set -e`** (errexit) — exit on any command failure.
  *Gotcha:* does NOT fire inside `if`/`while` conditions, left of `&&`/`||`, or
  after `!`. Expected failures: write `cmd || true`.
- **`set -u`** (nounset) — referencing an unset variable is a hard error. The
  Steam-bug preventer.
- **`set -o pipefail`** — a pipeline fails if ANY stage fails, not just the last.
  Without it, `tar ... | gzip > out.gz` reports success even if `tar` died and the
  backup is empty. (Verified: `grep zzz f | wc -l` → exit 0 without pipefail,
  exit 1 with it.)

## Lab 1: refactor a weapon into a tool
`unsafe-cleanup.sh` → `safe-cleanup.sh`. Static analysis (shellcheck) FIRST, then
harden. Findings on the unsafe version: SC2086 (unquoted vars), SC2045 (iterating
`ls`), SC2081 (`[ ]` can't glob-match), SC2046 (unquoted command substitution).

| Danger in unsafe version | Fix in safe version |
|---|---|
| `LOGDIR=$1` unquoted, empty → `rm -rf /*.tmp` | `${1:?usage}` guard — refuses to run |
| No directory validation | `[[ -d "$LOGDIR" ]]` before any delete |
| ``for f in `ls $LOGDIR` `` — breaks on spaces | `for f in "$LOGDIR"/*.log` — glob, quoted |
| `[ $f == *.log ]` — test can't glob-match | glob loop matches `.log` directly |
| no harness | `set -euo pipefail` |
| glob matching nothing → processes literal `*.log` | `shopt -s nullglob` |

**Verification (behavior, not just the linter):**
- `safe-cleanup.sh ~/testlogs` → archived 3 `.log` files **including `weird name.log`**
  (the spaced filename the unsafe version would shatter)
- `safe-cleanup.sh` (no arg) → refused: `usage: safe-cleanup.sh <log-directory>`
- `safe-cleanup.sh /nonexistent` → `error: '/nonexistent' is not a directory`

Note: `tar: Removing leading '/' from member names` is a tar *courtesy* (stores
relative paths so extraction can't overwrite real dirs), not an error.

## Lab 2: log parser (surfacing attack patterns)
`parse-log.sh <file>` — same guards (`${1:?}`, `[[ -f ]]`, `set -euo pipefail`) —
reports total requests, top-5 IPs, and 401 count.

Core pipeline:
```bash
awk '{print $1}' "$LOGFILE" | sort | uniq -c | sort -rn | head -5
```
- `awk '{print $1}'` — first field (IP). **Single quotes** so bash leaves `$1`
  alone and awk reads it as awk's field, not the script's argument.
- `sort` — group identical IPs (required before uniq)
- `uniq -c` — collapse dupes, prepend count
- `sort -rn` — by count, reverse, numeric
- `head -5` — top 5

**Security finding from the sample log:**
- `10.0.0.5` — 5 requests, all 401, all `POST /login` → **brute-force login attack**
- `203.0.113.7` — `/admin` (403) then `/../../etc/passwd` (404) → **path-traversal probe**

The script doesn't just count — it surfaces attacker behavior. That reading is the
deliverable.

## Key mechanisms banked
- **`"cmd"` stores text; `$(cmd)` runs it.** `echo "..."` only prints — a command
  inside it becomes text, never action. For a command's output: own line (→ screen)
  or `$(...)` (→ variable).
- **`$1` in single quotes** → bash leaves it (awk gets it); in double/bare → bash
  expands first. awk programs always use single quotes.
- **`bash script.sh` needs read; `./script.sh` needs read + execute.** `bash x.sh`
  runs the bash program with the file as input; `./x.sh` asks the kernel to execute
  the file directly (reads the shebang, requires the `x` bit). `chmod +x` for the
  production form.
- **Linter passing ≠ correct.** shellcheck validates shell *grammar*, not whether
  logic does what you intend. Always verify behavior on good, empty, and bad input.

## SOC 2 mapping
- Hardened, guarded scripts (no injection, no accidental destruction) → **CC6.1**
  (least privilege — a script can't exceed its intended action) and **CC8.1**
  (change management — scripts are reviewed, shellcheck-gated, version-controlled).
- Log parsing that surfaces brute-force / traversal patterns → **CC7.2 / CC7.3**
  (detection and analysis of security events).

## Artifacts
- `day-04-scripts/unsafe-cleanup.sh` — the deliberately unsafe original (kept as contrast)
- `day-04-scripts/safe-cleanup.sh` — hardened, shellcheck-clean, behavior-verified
- `day-04-scripts/parse-log.sh` — guarded log parser
- `day-04-scripts/sample-access.log` — sample data