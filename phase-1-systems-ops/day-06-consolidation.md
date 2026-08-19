# Day 6 — Consolidation: Debugging Method & Triage Drill

> **Document note:** written retrospectively during Checkpoint 1 (Day 12). The
> work, terminal output and grading below are from the Day 6 session as recorded;
> only this write-up is late. Flagged rather than back-dated.

## Purpose of a consolidation day
Not new material. Recall under pressure, a timed incident scenario, portfolio and
resume work while the details are fresh, and buffer for catch-up.

---

## 1. Recall drill — Days 1–5: **71%** (below the 80% bar)

Three items decayed and were re-drilled at the start of Day 7:

1. **`set -e` vs `set -u` vs `${var:?}`** — three different jobs, none substitutes
   for another. Command failure / unset variable / set-but-empty.
2. **Per-repo GPG keys (`signed-by=`)** beat the old global `apt-key` store
   because of **scope of trust** — globally, any trusted key could vouch for *any*
   repository. Not "better verification."
3. **A setuid binary is a finding based on whether it genuinely needs root and
   whether it is audited** — not on its permission bits or who can execute it.

---

## 2. The four-step debugging method

The drill was opened as a timed exercise and the honest response was *"no idea
where to begin."* That was a **method** gap, not a knowledge gap — every tool
needed was already known. The clock was stopped and the method taught mid-session;
a timed re-run is scheduled for Day 42.

> **1. Observe** — get the symptom from the system, not the ticket. The ticket says
> "the service is down"; the system tells you *how*.
> **2. Read the error** — actually read it. Errors usually name the cause. The most
> common failure is skimming and guessing.
> **3. Localize** — which layer? Service config, the thing it runs, permissions on
> that thing, the filesystem beneath it? Narrow before touching anything.
> **4. Fix ONE thing, then verify.** Never change two things at once — you won't
> know which one worked.

**Underneath it:** *the system will tell you what's wrong if you ask the right
question.* Knowing which question is just knowing your tools.

### Additions for real incidents (not drills)

**Step 0 — "what changed?"** Most incidents follow a deploy, a config edit, a
package upgrade, a certificate expiry, or a disk that finally filled.
```bash
journalctl --since "2 hours ago"
grep -E "install|upgrade|remove" /var/log/dpkg.log | tail -20
```

**Broaden before narrowing** when the failing component is unknown:
```bash
systemctl --failed ; df -h ; free -h ; uptime ; journalctl -p err -b | tail -40
```

**Time correlation is the strongest single tool:** *"failures started at 03:14 —
what else happened at 03:14?"*

---

## 3. Triage drill — three faults, presented as an incident ticket

> **INCIDENT — 03:14 local. Three alerts, one host.**
> 1. `webapp.service` is down and will not start.
> 2. Disk-full alarm on `/srv/appdata`. Writes failing.
> 3. Analyst team can no longer save files to `/srv/reports`.

Faults seeded blind via an encoded script — symptoms only, no causes.

### Fault 1 — service will not start (guided)

**Observe:**
```
× webapp.service - Webapp API service
     Active: failed (Result: exit-code)
    Process: 103831 ExecStart=/opt/webapp/run.sh (code=exited, status=203/EXEC)
Aug 09 13:05:36 (run.sh)[103831]: webapp.service: Unable to locate executable
                                  '/opt/webapp/run.sh': Permission denied
```

**`status=203/EXEC` is the diagnosis in a code** — systemd read the unit fine,
tried to *execute* the `ExecStart` target, and couldn't. A very narrow failure
class: the thing exists but can't be run. Not a config typo, not a missing
dependency, not a crash.

**One correction made during the session:** the first hypothesis was *"it can't run
because it's owned by root."* Ownership isn't the problem — `healthmon` from Day 3
is root-owned `755` and runs perfectly as user `healthmon`. The question is **does
it have `x` at all, and for whom?** The file was mode `644` — no execute bit for
anyone.

**Fix and verify — three separate layers:**
```bash
sudo chmod +x /opt/webapp/run.sh
ls -l /opt/webapp/run.sh                       # the FILE changed
sudo systemctl start webapp.service
systemctl status webapp.service --no-pager     # the SERVICE started
journalctl -u webapp.service --no-pager -n 5   # it is DOING ITS JOB
```
```
Active: active (running)
run.sh[111364]: webapp heartbeat 2026-08-09T13:42:42+02:00
```

> **"It started" and "it's working" are different claims.** The Day-5 backup
> assurance ladder applied to a service.

### Fault 2 — filesystem full (hinted)

```
tmpfs   20M   20M     0  100% /srv/appdata
20M     /srv/appdata/app.log
```

Initial instinct was *"archive rather than delete — the mature choice."* The
evidence overturned it:

```bash
$ sudo file /srv/appdata/app.log
/srv/appdata/app.log: data
$ sudo head -c 200 /srv/appdata/app.log | xxd | head -2
00000000: 0000 0000 0000 0000 0000 0000 0000 0000  ................
$ sudo lsof /srv/appdata/app.log
(no output)
```

**`file` said `data`, not `ASCII text`.** A real log reports as text. `xxd`
confirmed why: all null bytes. There was nothing to archive — archiving 20 MB of
zeroes preserves no information.

> **Updating a decision when evidence contradicts it is the hardest habit in
> incident response**, and it happened here unprompted.

`lsof` empty → no live writer → `truncate` and `rm` equally safe. Truncate chosen
as the better default habit:
```bash
sudo truncate -s 0 /srv/appdata/app.log
df -h /srv/appdata      # 0%
```

**Why truncate is the safer reflex:** `rm` removes the *directory entry*, but if a
process still holds the file open, **the space is not freed** until it closes.
That's the classic "I deleted it and `df` still says 100%" incident. `truncate -s 0`
works with a live writer.

**Also banked:** `df -i` for **inode** exhaustion — a filesystem can report free
space and still refuse writes.

**The step most people skip:** *why did it fill?* A log with no rotation refills
next week. **"Cleared the disk" closes the ticket; "cleared the disk and added
rotation" closes the incident.**

### Fault 3 — shared directory permissions (solo)

**Reproduce the symptom first** — you cannot verify a fix you can't observe:
```bash
$ sudo -u alice touch /srv/reports/test.txt
touch: setting times of '/srv/reports/test.txt': Permission denied
$ sudo -u alice ls -ld /srv/reports
drwx------ 2 root root 4096 /srv/reports
```

`700 root:root` — alice had no path in at all.

**The fix built to correct, not merely working:**
```bash
sudo chgrp analysts /srv/reports
sudo chmod 3770 /srv/reports          # setgid(2) + sticky(1) + 770
sudo setfacl -d -m g::rwx /srv/reports
```
```
drwxrws--T+ 2 root analysts 4096 /srv/reports
```

No reach for `chmod 777` — the "make the error go away" move that creates a
permanent finding. Each bit does a distinct job:
- **setgid** → files created inside inherit group `analysts` (collaboration)
- **sticky** → a user can delete only their own files
- **`other: ---`** → non-members cannot even traverse in
- **default ACL** → new files land group-writable, closing the Day-2 trap where
  setgid gives group *ownership* but not group *write*

**Paired verification — both halves of the requirement:**
```bash
$ sudo -u alice bash -c 'echo data > /srv/reports/shared.txt'
$ sudo -u alice ls -l /srv/reports/shared.txt
-rw-rw---- 1 alice analysts 5 /srv/reports/shared.txt
$ sudo -u bob touch /srv/reports/should-fail.txt
touch: setting times of '/srv/reports/should-fail.txt': Permission denied
```

> **A permissions fix has two acceptance criteria: the right people gained access
> AND the wrong people didn't.** Testing only the positive case is how a `777`
> ships as "fixed."

---

## 4. Grade — strong pass

Once started, every fault followed symptom → evidence → hypothesis → targeted fix
→ verification, with no simultaneous changes. Fault 2 saw a plan revised against
contradicting evidence. Fault 3 was solo, reproduced before touching anything, and
built to the correct standard rather than the working one.

The only real stumble was the opening — a method gap that closed within one fault.

---

## 5. Portfolio & career output
- **`README.md`** — repo front page: selected-work table with control mappings
- **`career/resume-bullets-day06.md`** — 8 bullets tagged to target roles, each
  with an **interview-defence line**

**Note recorded at the time, and borne out at Checkpoint 1:** every bullet is
defensible only if the mechanism can be explained under questioning. Interview
threads were averaging 50–70% on exactly that. *The work is real; the narration is
the lagging skill.*

---

## SOC 2 mapping
| Artifact | Criterion |
|---|---|
| Documented triage method + incident runbook | **CC7.3** (incident response procedures) |
| Paired positive/negative access verification | **CC6.1** (least privilege, evidenced) |
| "What changed?" correlation via dpkg/journal | **CC7.2** (log-based investigation) |
| Service restored and verified functional | **A1.2** (availability) |

## Concepts banked
- Four-step method: **Observe → Read → Localize → Fix ONE thing + verify**
- `203/EXEC` = cannot execute the ExecStart target (vs. program ran and failed)
- `file` says `data` not `ASCII text` → binary, nothing to archive
- `lsof` **before** deleting large files; deleted-but-held-open ≠ space freed
- `df -i` for inode exhaustion
- **Ticket closed ≠ incident closed** — fix the cause, not the symptom
- Shared dirs: setgid (ownership) + default ACL (write) + sticky (delete) — three
  independent levers
- Reproduce the symptom before fixing; verify as the identity under test