# Agent 1 — Demo Transcript

**Agent:** Server Health Monitor (MCP, stdio transport)
**Host:** `devsecops90` (Ubuntu 26.04, WSL2)
**Client:** Claude Code
**Server:** `health-monitor` — one tool, `run_audit`, read-only, no arguments

> **Note on fidelity:** captured from a terminal session where line-wrapping
> truncated words mid-sentence. Fragments have been reconstructed from context;
> substance is unchanged. Raw capture retained alongside this file.

---

## Setup

### Registration
```bash
claude mcp add health-monitor -- \
  /home/bassam/agents/health-monitor/.venv/bin/python \
  /home/bassam/agents/health-monitor/server.py
```
```
Added stdio MCP server health-monitor with command:
  /home/bassam/agents/health-monitor/.venv/bin/python
  /home/bassam/agents/health-monitor/server.py to local config
File modified: /home/bassam/.claude.json
```
```bash
claude mcp list
```
```
health-monitor: .../.venv/bin/python .../server.py - ✔ Connected
```

### Seeded misconfigurations
Three faults planted deliberately, all reversible:

| # | Fault | Command |
|---|---|---|
| 1 | Rogue SUID-root binary in a home directory | `chmod 4755 /home/bassam/.cache/backup-helper` (owned `root:root`) |
| 2 | World-writable file owned by root | `chmod 0666 /opt/maintenance.sh` |
| 3 | Blanket passwordless sudo | `deploy ALL=(ALL) NOPASSWD: ALL` in `/etc/sudoers.d/99-deploy-bad` |

### Observer output before the demo
```
no-ww-files|FAIL|/opt/maintenance.sh;
no-rogue-suid|FAIL|/home/bassam/.cache/backup-helper;
no-nopasswd-all|FAIL|/etc/sudoers.d/99-deploy-bad;
```

---

## The exchange

### Prompt
> Run a security audit of this host. For each failing check, explain what an
> attacker could actually do with it, and rank the failures by which you would
> fix first.

### Tool invocation
```
I'll load the health-monitor audit tool and run it against this host.
Now running the audit.

  Called health-monitor
```

The model called `run_audit` rather than attempting shell access — the tool
surface was the only route available to it.

### Response

**Audit result: 8/11 passed, 3 failed (all High severity)**

> Ran the CIS-subset audit against `devsecops90`. The 3 failures are all local
> privilege-escalation paths — nothing here is remotely exploitable on its own,
> but each one turns "I have a shell" into "I have root."

#### Ranked by fix priority

**1. Rogue SUID root binary — `/home/bassam/.cache/backup-helper`**
```
-rwsr-xr-x 1 root root  /home/bassam/.cache/backup-helper
```
> This binary runs as root regardless of who executes it. It sits in a user cache
> directory (not a package-managed location), and isn't owned by any installed
> package — meaning nobody is tracking or auditing what it does. Any local user —
> no sudo rights, no special account needed — can run `~/.cache/backup-helper`
> directly and get root. And if the directory itself is writable by more than one
> user, an attacker doesn't even need the original binary to be dangerous: they
> can overwrite it with a shell-spawning payload and it stays SUID-root. This is
> the most broadly exploitable of the three and requires the least — just local
> execute access, which almost anyone on the box already has.
>
> **Fix first:** verify what it's for, then either remove it or strip the SUID bit
> and re-attribute it to a package.

**2. Blanket `NOPASSWD:ALL` sudoers rule — `/etc/sudoers.d/99-deploy-bad`**
> This grants passwordless root for any command to whatever account it's scoped to
> (name suggests a deploy/automation user). The danger: it removes the
> re-authentication barrier entirely. If that account's key, API token, or CI
> credential leaks — or if a deploy script running as that user has an RCE bug —
> the attacker doesn't need to guess a password or catch a live sudo session; they
> get instant, silent root the moment they land a shell as that user. Deploy
> accounts are also disproportionately likely to be reachable from CI systems or
> scripts outside this host, which widens the realistic attack surface versus a
> purely-local account.
>
> **Fix:** replace with a scoped rule listing only the specific commands it
> genuinely needs.

**3. World-writable file owned by root — `/opt/maintenance.sh`**
```
-rw-rw-rw- 1 root root  /opt/maintenance.sh
```
> Any local user can overwrite this file's contents. It's only dangerous if
> something runs it as root (cron job, systemd timer, or an admin manually running
> it with sudo) — at which point whatever an attacker wrote executes as root. I
> ranked this third because it's execution-dependent (an attacker has to know or
> wait for it to run), not immediately exploitable like the two above — but it
> should still be fixed today: `chmod o-w /opt/maintenance.sh`, and check
> `crontab -l` and systemd timers to see if anything actually invokes it as root,
> which would tell you how "live" this hole really is.

#### What's already solid
> Firewall (ufw enabled, default-deny inbound), fail2ban running, no
> empty-password accounts, `/etc/shadow` correctly locked to 640, only one UID 0
> account, nginx version banner suppressed, and automatic security updates
> configured — all passing, no action needed.

#### Caveat
> This is a CIS subset, not a full compliance sweep — a clean score means these 11
> checks passed, not that the host is broadly secure (open ports, TLS config,
> kernel hardening and application security aren't covered here).

---

## Acceptance assessment

| Criterion | Result |
|---|---|
| Detects 3 seeded misconfigurations | **Pass** — all three, correctly identified |
| Each finding maps to its CIS item | **Pass** — 6.1.13, 5.3.4, 6.1.9 |
| Model uses the tool rather than shell access | **Pass** — `run_audit` called; no shell attempted |
| Scope note respected | **Pass** — reproduced in the closing caveat |

### Reasoning beyond the supplied data — the point of the exercise

The tool returned all three failures tagged `severity: high`. The model did **not**
simply sort by that label:

1. **Re-ranked by realistic exploitability.** SUID first (needs only local execute
   access, which most accounts already have), sudoers second (widens beyond the
   host to CI and automation credentials), world-writable third — explicitly
   because it is *execution-dependent*: something else must run it as root before
   it becomes exploitable. **That ordering was not present in the input.**

2. **Surfaced a second-order risk not encoded anywhere.** If the *directory*
   containing the SUID binary is writable, an attacker can replace the binary
   entirely and it remains SUID-root. Neither the audit script nor `CHECK_META`
   mentions directory permissions.

3. **Proposed an investigative next step** for finding 3 — check `crontab -l` and
   systemd timers to determine whether anything actually invokes the file as root,
   which converts a theoretical finding into a measured one.

### Division of labour — confirmed
- **Deterministic layer produced the facts.** Every file path, permission mode and
  pass/fail state came from the root-owned bash observer. Nothing about host state
  was invented.
- **Model produced the judgement.** Prioritisation, attack narrative, second-order
  risk and investigative next steps.

> **Evidence is generated by deterministic tooling and interpreted by a model —
> never the reverse.**

### Note on the audit validating its own privilege grant
`no-nopasswd-all` continued to **PASS** despite the agent's own sudoers rule
(`bassam ALL=(root) NOPASSWD: /usr/local/bin/cis-audit-json.sh`), because the check
matches `NOPASSWD:` followed by `ALL` — distinguishing a **scoped** grant
(acceptable) from a **blanket** one (a finding). A check unable to distinguish
those would be useless.

---

## Teardown
```bash
sudo rm -f /home/bassam/.cache/backup-helper \
           /opt/maintenance.sh \
           /etc/sudoers.d/99-deploy-bad
sudo -n /usr/local/bin/cis-audit-json.sh | grep -c PASS   # → 11
```