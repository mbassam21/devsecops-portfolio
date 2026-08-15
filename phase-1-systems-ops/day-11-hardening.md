# Day 11 — Hardening: Evidence Pack

## Security thread
**The whole day.** Every prior control protected something specific — a service, a
script, a connection. This day hardens **the host itself**, and the framing shifts
from *"is this configured correctly"* to **"what would an auditor or an attacker
find if they looked?"** That is the deliverable shape: measured state before,
controls applied, measured state after, limitations stated.

---

## 1. Baseline (before)

| Check | Result |
|---|---|
| Accounts with empty passwords | **None** ✓ |
| World-writable files outside `/tmp` | **None** ✓ |
| Login-capable accounts | root, bassam, alice, bob (+ `sync`, a standard system account) |
| SUID inventory | Standard set + **one finding** (below) |
| Host firewall | **Not installed** ✗ |
| fail2ban | **Not installed** ✗ |
| sshd | Not present in this instance |

### FINDING: unowned SUID file outside system paths
```
/home/bassam/perms-lab/demo-suid
```
Created during the Day-2 permissions lab and left in place. Applying the Day-2
audit question — *does it need root, is it audited, does a package own it?* —
gives **no, no, and no**.

**This is exactly the finding class reported in a real assessment:** a SUID file
in a user home directory, owned by no package, unaudited. Harmless here (an empty
file, not an executable), but the lab produced a genuine finding of the type it
teaches you to look for.

**Remediated:** removed, re-verified empty across `/home`, `/opt`, `/srv`.

All remaining SUID binaries attributed to owning packages (`passwd`, `sudo`, `su`,
`mount`, `umount`, `chsh`, `chfn`, `gpasswd`, `fusermount3`, `ssh-keysign`,
`dbus-daemon-launch-helper`).

---

## 2. Host firewall — deny by default

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 8080/tcp comment 'nginx http redirect'
sudo ufw allow 8443/tcp comment 'nginx https'
sudo ufw --force enable
```

```
Status: active
Default: deny (incoming), allow (outgoing), deny (routed)
8080/tcp    ALLOW IN    Anywhere    # nginx http redirect
8443/tcp    ALLOW IN    Anywhere    # nginx https
```

**Deny by default, permit by exception.** The same principle as the `3770` shared
directory (`other` gets nothing) and `CapabilityBoundingSet=` (drop everything,
add nothing back). The most consistently correct security posture available.

**Stated limitation:** on a single-host lab the ruleset can be verified as
*loaded*, but not as *blocking a remote attacker* — loopback traffic bypasses the
INPUT chain. Genuine verification requires a second host. Recorded rather than
overclaimed.

---

## 3. fail2ban — log-driven dynamic blocking

Three components: a **filter** (regex matching failures in a log), a **jail**
(which log, which filter, what thresholds), an **action** (usually a firewall ban).

```ini
[nginx-limit-req]
enabled  = true
port     = 8080,8443
filter   = nginx-limit-req
logpath  = /var/log/nginx/error.log
maxretry = 10
findtime = 60
bantime  = 600

[sshd]
enabled = false      # no sshd in this instance; retained as reference
```

The jail consumes the **429 rate-limit events from Day 10** — an IP tripping
nginx's limit 10 times in 60 seconds is banned at the firewall for 10 minutes.

**Defence in depth, made concrete:** nginx returns 429s (cheap, per-request);
fail2ban escalates persistent offenders to a **network-level block**, so their
packets stop reaching nginx at all.

### Evidence — detection confirmed, ban correctly suppressed
40 rapid requests generated rate-limit events. `/var/log/fail2ban.log`:
```
[nginx-limit-req] Ignore ::1 by ignoreself rule      ×20
```
**The filter matched every violation.** The ban action was suppressed because the
source was the local machine — the `ignoreself` default. This is correct
behaviour: banning yourself from your own server is a classic self-inflicted
outage.

> Evidence statement: *filter proven functional; ban action correctly suppressed
> for local traffic. Ban enforcement itself requires a remote source to verify.*

---

## 4. Hardened `sshd_config` (reference artifact)

**Not operational in this environment — no sshd runs in this instance.** Validated
with `sshd -t -f <file>` → **CONFIG SYNTAX OK**, the same discipline as `nginx -t`.
Labelling an untested control honestly *is* the professional standard.

| Directive | Justification |
|---|---|
| `PermitRootLogin no` | Named-user accountability; removes the highest-value brute-force target |
| `PasswordAuthentication no` + `PubkeyAuthentication yes` | **Eliminates credential stuffing against SSH entirely** — passwords are guessable, reusable, phishable; keys are not |
| `MaxAuthTries 3` | Limits guesses per connection; forces reconnection, which fail2ban can observe |
| `LoginGraceTime 30` | Unauthenticated connections are cheap to hold open |
| `AllowUsers deploy admin` | Deny-by-default at the authentication layer |
| `X11Forwarding no`, `AllowAgentForwarding no`, `AllowTcpForwarding no`, `PermitTunnel no` | Each forwarding feature is a **pivot path** to systems the SSH host can reach but the attacker cannot |
| Modern `KexAlgorithms`/`Ciphers`/`MACs` only | Same reasoning as removing TLS 1.0/1.1 (Day 8): **a supported weak algorithm is reachable via downgrade regardless of client preference** |
| `LogLevel VERBOSE` | Records key fingerprints — proves *which key* authenticated. Forensic evidence (CC7.2) |
| `ClientAliveInterval 300` / `CountMax 2` | Reclaims unattended authenticated sessions |
| `Banner /etc/issue.net` | Unauthorized-access notice; matters for prosecution in many jurisdictions |

---

## 5. CIS-subset audit

`cis-audit.sh` — 12 automated checks, shellcheck-clean, producing a pass/fail
score. **This script is the direct ancestor of Agent 1 (Day 12)**, which will run
the same audit and return structured JSON.

```
=== CIS-subset audit: devsecops90 ===
[PASS] Firewall (ufw) is active
[PASS] Default deny incoming policy
[PASS] fail2ban service is running
[PASS] No accounts with empty passwords
[PASS] No world-writable files outside /tmp
[PASS] No unowned SUID binaries in /home,/opt,/srv
[PASS] /etc/shadow is 640 or stricter
[PASS] /etc/passwd is not world-writable
[PASS] Root is the only UID 0 account
[PASS] sudo requires authentication (no global NOPASSWD:ALL)
[PASS] nginx hides version (server_tokens off)
[PASS] Automatic security updates configured
---
PASS: 12  FAIL: 0  SCORE: 100%
```

### Honest reading of a 100% score
**A perfect score on a checklist you wrote yourself is weak evidence.** The score
measures *"does this host pass the tests I chose"*, not *"is this host secure."*
A client reading "12/12 PASS" should ask **who picked the 12** — and the answer
must be ready.

Specifically:
- Several checks passed **because of the environment**, not because of work done
  today — no world-writable files and no empty passwords were true of the fresh
  image. Baseline hygiene, not remediation.
- **The checks that genuinely flipped FAIL → PASS today:** the unowned SUID
  binary, ufw active, default-deny incoming, and fail2ban running. That is the
  real before/after, and stating it precisely is better than hiding it inside a
  perfect score.

---

## 6. Environmental constraint — ports 22 and 80

Ports 22 and 80 appear **LISTEN with an empty Process column** in this instance —
the same signature as the Day-9 collision. The listeners are owned by processes
in the **other WSL2 instance**, which shares this network namespace.

> **Finding:** ports 22/80 observed listening in the lab instance's network view
> but owned by processes outside its namespace (WSL2 shared networking). The lab
> host **cannot enforce controls on these listeners**. Host-level firewall rules
> apply only to services owned by this instance. Documented as an environmental
> constraint.

### Incident: collateral damage from chasing the symptom
Attempting to eliminate the foreign listener from the **other** machine caused
real damage there: `apt purge openssh-client` cascaded into removing `snapd`,
`ssh-import-id`, `xauth`, `fuse3` and `squashfs-tools`, and left `dpkg` in a
permanently failing state (an unrelated `passbolt-ce-server` post-install script
error surfacing after every apt operation).

**Lesson — the most valuable of the day.** The blast-radius discipline that
justified building an isolated lab on Day 1 was set aside the moment the problem
*appeared* to live elsewhere. **That is precisely how production incidents
happen:** someone reaches outside the change window to fix an annoyance. The
correct response to an out-of-scope finding is to *document it*, not to chase it
onto a system you depend on.

---

## SOC 2 mapping
| Control | Criterion |
|---|---|
| Host firewall, default-deny inbound | **CC6.6** (boundary protection) |
| SUID remediation; root-only UID 0; no global `NOPASSWD:ALL` | **CC6.1** (least privilege) |
| sshd key-only authentication, allowlisted users | **CC6.1 / CC6.2** (authentication and authorization) |
| fail2ban dynamic blocking on observed abuse | **CC6.6 / CC7.3** (detection and response) |
| `LogLevel VERBOSE` key-fingerprint logging | **CC7.2** (forensic evidence) |
| Repeatable CIS-subset audit with before/after evidence | **CC7.1** (detecting configuration drift) |
| Automatic security updates | **CC7.1 / CC6.8** (patch currency) |

## Artifacts
- `day-11-hardening/cis-audit.sh` — 12-check audit script (shellcheck-clean)
- `day-11-hardening/audit-before.txt` / `audit-after.txt` — evidence pair
- `day-11-hardening/sshd_config.hardened` — reference config, syntax-validated
- `day-11-hardening/jail.local` — fail2ban configuration
- `day-11-hardening/ufw-status.txt` — firewall ruleset