# Day 03 — Processes, systemd & Packages

## Security thread
1. **Why services never run as root** → SOC 2 **CC6.1** (logical access controls).
   A service exploited via RCE runs as *its own user*. If that user is root, the
   attacker gets instant, total compromise. If it's a dedicated low-privilege
   user in a sandbox, the attacker is contained and needs a *second* vulnerability
   to escalate. Running non-root converts "one bug = own the box" into "one bug =
   trapped in a near-empty sandbox."
2. **Package integrity** → SOC 2 **CC6.8** (controls against unauthorized/malicious
   software). `apt` installs packages *as root*; GPG signature verification proves
   a package came from the claimed source and wasn't tampered with in transit.

## Process model (reference)
- A process has a **PID**, a **PPID** (parent), and runs **as a user (UID)** — the
  UID is the security-relevant fact: it bounds what the process (and anyone who
  hijacks it) can do.
- Every process traces up to **PID 1** (systemd on a systemd host); PID 1 adopts
  orphaned children and reaps zombies.
- **The one question to always ask:** *what user is this process running as?*
- Root attack surface = count of root processes. Each exploitable root process is
  a direct, no-escalation path to full control. Every *unnecessary* root process
  is a cost, not a neutral.
- `/proc/<pid>/` = the kernel's live, per-process truth (cmdline, comm, cwd, etc.).

Useful inventory commands:
```bash
ps -eo pid,ppid,user,comm --forest      # process tree with ancestry
ps -eo user | tail -n +2 | sort | uniq -c | sort -rn   # processes per user (root surface)
ps -p 1 -o pid,ppid,user,comm           # confirm PID 1 = systemd
```

## Lab: custom non-root service + timer

### 1. Dedicated system user (minimal identity)
```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin healthmon
```
- `--system` → UID < 1000, a service account, not a person
- `--no-create-home` → no home dir = smaller attack surface
- `--shell /usr/sbin/nologin` → **cannot get an interactive shell** if compromised

Result: `uid=999(healthmon)`, no supplementary groups — a minimal identity by design.

### 2. The script (owned by root, executable by the service)
`/opt/healthmon/health-check.sh`, mode 755, **owner root:root**. The service user can
*execute* it but **cannot modify** it — so a compromised `healthmon` account can't
rewrite its own code. Uses `set -euo pipefail` to fail loudly on any error.

### 3. Service unit — `/etc/systemd/system/healthmon.service`
- `[Unit]`: metadata + ordering (`After=network.target`, `Documentation=` → repo)
- `[Service]`: `Type=oneshot` (runs once, exits), `User=/Group=healthmon` (**non-root**),
  `ExecStart=` the script
- **Hardening block** — sandboxing that holds *even if the service is exploited*:
  - `NoNewPrivileges=true` → children can never gain privileges; **neutralizes the
    entire setuid-escalation path** for this service
  - `ProtectSystem=strict` → whole filesystem read-only except explicit paths
  - `ProtectHome=true` → /home, /root invisible
  - `PrivateTmp=true` → isolated /tmp (sidesteps the shared-/tmp sticky-bit problem)
  - `ReadOnlyPaths=/opt/healthmon` → even its own dir is read-only

A successful `oneshot` ends in `inactive (dead)` — that is **success** (job done,
process exited), not a failure.

### 4. Timer — `/etc/systemd/system/healthmon.timer`
The `.service` says *what*; the same-named `.timer` says *when*.
- `OnBootSec=2min` → first run 2 min after boot
- `OnUnitActiveSec=10min` → then every 10 min
- `Persistent=true` → **catches up missed runs** after downtime (cron silently skips)
- `WantedBy=timers.target` → enable at boot

```bash
sudo systemctl enable --now healthmon.timer
systemctl list-timers        # auditor's view: next/last run for every timer
```

## systemd timers vs cron (interview differentiator)

| Property        | cron                                   | systemd timer                              |
|-----------------|----------------------------------------|--------------------------------------------|
| Logging         | none by default (output vanishes)      | every run in the journal (`journalctl -u`) |
| Missed runs     | silently skipped                       | `Persistent=true` catches up               |
| Sandboxing      | minimal                                | full unit hardening applies                |
| Auditability    | scattered per-user crontabs, hideable  | one `list-timers`, unit files in Git        |
| Change tracking | none                                   | unit files version-controlled + diffable   |

**Finding pattern (Adwen):** scheduled jobs in cron with no execution logging or
central visibility → recommend systemd timers (or logged cron + monitoring). Rogue
crontab entries are a classic persistence trick; a timer is a *file* that shows up
in `list-timers`, logs every run, and can be committed to Git.

## Hardening evidence — measured, remediated, re-measured

`systemd-analyze security healthmon.service` gives an exposure score
(0.0 locked down → 10.0 wide open), line-by-line per directive.

| Stage                                    | Exposure score      |
|------------------------------------------|---------------------|
| Baseline (initial hardening block)       | **8.3 — EXPOSED**   |
| After full lockdown (below)              | **1.9 — OK**        |

Directives added to reach 1.9 (and *why the service still works*):
- `PrivateNetwork=true` — no network namespace at all (health check reads local
  files only); killed the single largest score line (0.5) and blocks phone-home/pivot
- `CapabilityBoundingSet=` (empty) — drops **all** Linux capabilities; service needs none
- `SystemCallFilter=@system-service` — seccomp allowlist; non-service syscalls return
  EPERM, shrinking kernel attack surface
- `RestrictSUIDSGID=true` — can't create setuid/setgid files (closes escalation primitive)
- `RestrictNamespaces`, `ProtectKernelTunables/Modules/ControlGroups`,
  `LockPersonality`, `MemoryDenyWriteExecute`, `RestrictAddressFamilies=AF_UNIX`

**Key result:** exposure cut from 8.3 → 1.9 with **function preserved** (service
still emits its health snapshot). The one remaining item, `UMask=` (0.1), is
harmless here (service writes nothing to disk). *Knowing when to stop chasing the
last 0.1 is part of the skill.*

## Package integrity (CC6.8)
`apt` refuses to install from a repo unless packages are cryptographically signed by
a trusted key, and verifies every download against that signature. Without it, a
compromised mirror or MITM could serve a malicious package that installs **as root**
— a supply-chain catastrophe. This is why the Day-1 Docker install added the GPG key
*before* the repo.

**Modern (correct) key model:** a *per-repo* key in `/etc/apt/keyrings/docker.asc`,
bound to that one repo via `signed-by=`. The deprecated global `apt-key` store is
removed in current Ubuntu because any trusted key there could sign *any* repo — a real
weakness. Per-repo keys mean Docker's key vouches for Docker packages **only**.

## SOC 2 mapping
- Non-root service + sandbox hardening (measured 8.3→1.9) → **CC6.1** (least
  privilege at the service layer; exploit containment)
- GPG package signature verification, per-repo key model → **CC6.8** (defense
  against unauthorized/malicious software)
- Timer-based scheduled jobs with journald logging → **CC7.2** (system operations
  are logged and reviewable)

## Artifacts
- `day-03-units/healthmon.service` — hardened non-root service unit
- `day-03-units/healthmon.timer` — scheduling timer
- `day-03-units/health-check.sh` — the health-snapshot script