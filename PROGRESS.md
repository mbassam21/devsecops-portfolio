PROGRESS SNAPSHOT — Day 1 (2026-07-27)
Status: complete
Shipped:
  - Dedicated WSL2 lab instance `devsecops90` provisioned (git 2.53.0, Docker CE via official signed repo + docker group, Claude Code 2.1.220); baselined & patched
  - GitHub repo github.com/mbassam21/devsecops-portfolio (SSH/keyless auth via ed25519)
  - Phase scaffold (phase-1..5, capstone, agents) + secrets-first .gitignore
  - phase-1-systems-ops/day-01-environment.md — attack-surface baseline + isolation decision + CC7.1 mapping (commit 4f6154a)
Gaps/issues:
  - AWS account is FREE plan → auto-closes ~6mo, restricts services, Org-join expires credits. ACTION: upgrade to Paid before Day 13 + set $50 Budgets alarm on arrival.
  - Empty phase folders not tracked (add .gitkeep — command provided) so remote shows full structure.
  - Doc polish: name the 10.255.255.254:53 WSL-DNS bind in summary; ss output truncated; verify Docker version reflects devsecops90.
  - Optional/parked: WSL networking mode + Passbolt exposure note on MAIN box (attack-surface completeness, CC7.1).
  - Day-1 interview questions awaiting answers.
Next: Day 2 — Users, groups, permissions (chmod/chown, umask, setuid/setgid/sticky, sudoers). Thread: least privilege at the OS layer (CC6.1).

PROGRESS SNAPSHOT — Day 2 (2026-07-31)
Status: complete
Shipped:
  - Multi-user shared-directory lab: users alice+bob, group engineering, dir 3770 (setgid+sticky) + default ACL
  - PROVEN controls (terminal evidence): setgid group-inheritance ✓ ; sticky delete-protection (bob denied rm, file survived) ✓ ; group-write collaboration (bob edits alice's file) ✓
  - Scoped sudo: /etc/sudoers.d/bob-cron (440, visudo-validated), NOPASSWD on ONE command. PROVEN: restart cron ALLOWED; stop cron DENIED; cat /etc/shadow DENIED → CC6.1 admin-layer least privilege
  - Artifact: phase-1-systems-ops/day-02-permissions.md committed + pushed (commit ebde7f6)
  - Environment fix: enabled systemd in WSL2 via [boot] systemd=true in /etc/wsl.conf (was falling back to init shim)
Key lessons banked:
  - '>' truncates+recreates files at umask default, silently dropping an earlier chmod → per-file chmod is fragile; default ACLs (or 002 umask) are the durable fix. (The real root cause of the multi-session "group-writable file that wasn't" anomaly — NOT a filesystem bug.)
  - Debugging discipline: instrument (id / getfacl -n / lsattr) + minimal reproduction + read errors BY LAYER (authorization vs execution; permission-bits vs filesystem). When ROOT is denied a basic op, cause is below permissions.
Gaps/issues:
  - Day-2 interview questions (3) awaiting answers — grade at start of Day 3.
  - Optional doc polish: add authorization-vs-execution + WSL systemd-conf notes to war-story section (2 lines provided).
  - PARKED (from Day 1): AWS account is FREE plan → upgrade to Paid + set $50 Budgets alarm before Day 13.
  - PARKED (from Day 1): WSL networking mode + Passbolt exposure note on MAIN box (attack-surface completeness, CC7.1) — optional.
Next: Day 3 — Processes, systemd, packages (units, targets, timers vs cron, journalctl; apt/GPG signing). Thread: why services never run as root; package integrity. NOTE: you've already met how systemd fails ('Host is down' / init shim) — walk in with that context.

PROGRESS SNAPSHOT — Day 3 (2026-08-02)
Status: complete
Shipped:
  - Dedicated non-root system user `healthmon` (uid 999, nologin, no home)
  - health-check.sh (root-owned 755 — service can run, can't modify its own code)
  - healthmon.service — Type=oneshot, User=healthmon, full hardening block
  - healthmon.timer — OnBootSec/OnUnitActiveSec=10min, Persistent=true, enabled at boot; confirmed in list-timers, fired successfully
  - HARDENING BEFORE/AFTER: systemd-analyze security 8.3 EXPOSED → 1.9 OK, function preserved (PrivateNetwork, empty CapabilityBoundingSet, SystemCallFilter=@system-service, RestrictSUIDSGID, +more)
  - Verified modern per-repo GPG key model (/etc/apt/keyrings/docker.asc, signed-by=); apt-key correctly deprecated/empty
  - Artifact: day-03-services.md + day-03-units/ (service, timer, script) — commit pending confirmation
Key concepts banked:
  - "What user is this process running as?" as the core security question; root process count = attack surface
  - oneshot ending inactive(dead) = success, not failure
  - systemd hardening = exploit containment even WITHOUT a shell (NoNewPrivileges kills setuid escalation; PrivateNetwork blocks pivot; seccomp allowlist shrinks kernel surface)
  - timers > cron for logging, missed-run catch-up, sandboxing, auditability (Git-tracked unit files vs hideable crontabs)
  - GPG signature verification = supply-chain integrity; per-repo keys > global apt-key
Gaps/issues:
  - Day-3 interview questions (3) DEFERRED to start of Day 4 (late-night stop — clean recall signal preferred).
  - Day-2 interview questions were already graded (~63%): recurring pattern = correct conclusion, verify the MECHANISM. Keep adding the "because."
  - Optional: add UMask=0077 to unit for 1.9→1.8 (cosmetic; service writes nothing).
  - PARKED (Day 1): AWS FREE plan → upgrade to Paid + $50 Budgets alarm before Day 13.
  - PARKED (Day 1): WSL networking mode + Passbolt exposure note on MAIN box (CC7.1, optional).
Next: Day 4 — Bash I (variables, quoting, conditionals, loops, functions, exit codes, set -euo pipefail, shellcheck). Thread: unsafe scripts as an attack vector. START WITH: 3 deferred Day-3 interview questions.

PROGRESS SNAPSHOT — Day 4 (2026-08-06)
Status: complete
Shipped:
  - safe-cleanup.sh — hardened refactor of a deliberately unsafe script; shellcheck-clean; behavior-verified on good input (archived "weird name.log" w/ space), empty arg (refused via ${1:?}), bad dir ([[ -d ]] rejected)
  - parse-log.sh — guarded log parser; surfaced brute-force (10.0.0.5, 5×401 POST /login) + path-traversal (203.0.113.7, /../../etc/passwd) from sample log
  - unsafe-cleanup.sh kept as contrast artifact
  - day-04-bash.md + day-04-scripts/ (4 files) — commit pending confirmation
Concepts banked (mechanism-level):
  - Three distinct bug classes / three fixes: quoting (spaces+globbing) vs set -u (unset) vs ${var:?} (empty) — none substitutes for another
  - set -euo pipefail decoded incl. set -e's if/&&/|| gotcha and pipefail's silent-failure fix (verified exit 0→1)
  - "cmd" = text, $(cmd) = runs it; echo never executes its contents (learned via 3 real failures)
  - $1 in single quotes → bash leaves it (awk field) vs double/bare → bash expands
  - bash script.sh needs r; ./script.sh needs r+x (kernel reads shebang) — chmod +x both scripts
  - CRITICAL META-LESSON: shellcheck (grammar) passing ≠ logic correct. Verify BEHAVIOR on good/empty/bad input.
Coaching thread (recurring): pattern-matching to surface vs tracing mechanism — same gap as interview answers. Improving; today drilled it hard in-terminal. Keep adding the "because."
Gaps/issues:
  - Day-4 interview questions (3) awaiting answers — grade next session.
  - PARKED (Day 1): AWS FREE plan → upgrade to Paid + $50 Budgets alarm before Day 13.
  - PARKED (Day 1): WSL networking mode + Passbolt exposure note on MAIN box (CC7.1, optional).
Next: Day 5 — Bash II + automation (grep/awk/sed/jq, getopts, cron; INSTALL gitleaks pre-commit hook). Ship: production backup.sh w/ rotation+logging+failure alerting + cron entry + gitleaks hook. Thread: auditing crontabs, malicious persistence.

PROGRESS SNAPSHOT — Day 5 (2026-08-08)
Status: complete
Shipped:
  - backup.sh — production: guards, timestamped archives, log() w/ tee, trap ERR (TESTED, fired at line 31), tar tzf verification, find-based rotation. Evidence: 15 runs → exactly 5 retained.
  - gitleaks v8.30.1 installed with sha256 verification (551f6fc8…2470eb, confirmed vs release page)
  - .git/hooks/pre-commit — fail-closed secrets gate. PROVEN: blocked commit with 2 findings (private-key entropy 4.86, github-pat 4.77)
  - Repo history scanned clean: gitleaks git . → 4 commits, no leaks
  - Cron job installed + VERIFIED RUNNING UNDER CRON (cron.log full cycle), not just in shell
  - Full scheduled-execution audit: crontabs (user/root/system), /etc/cron.{d,hourly,daily,weekly,monthly}, /var/spool/cron/crontabs, systemd timers — all attributable, clean
  - day-05-automation.md + day-05-scripts/ (backup.sh, pre-commit, crontab-entry.txt)
Key lessons banked:
  - SCANNER LIMITS: gitleaks missed a raw AWS secret key (40 base64 chars = indistinguishable from hashes) — detects prefixed secrets only (AKIA/ghp_/xoxb-/BEGIN KEY). Every detector trades sensitivity vs false positives; know what yours MISSES.
  - Local hooks = convenience, not enforcement (not versioned, --no-verify bypasses) → CI-side scanning required (Phase 4)
  - Fail-closed control design (missing dependency must BLOCK, not pass)
  - Cron env trap: no profile loaded, minimal PATH → absolute paths; security variant = PATH hijacking (same root cause)
  - Day-2 callback in production: /var/spool/cron/crontabs is drwx-wx--T (1730) — setgid-style least privilege + sticky delete-protection, exactly the pattern built by hand
  - Backup assurance ladder: scheduling ≠ execution ≠ integrity ≠ RECOVERABILITY. Only a restore test proves the last.
Gaps/issues:
  - RESTORE DRILL not yet done (extract + diff -r vs source) — the missing piece of A1.2 evidence. 10-min task, commands provided.
  - Fix `set -eou pipefail` → `set -euo pipefail` in backup.sh
  - Day-5 interview ~60%. STANDING COACHING FOCUS through Checkpoint 1: answer ALL parts of the question, and check you're addressing the claim actually tested (Q2 missed the security variant; Q3 answered "did it run" instead of "does it work").
  - PARKED: AWS FREE plan → upgrade to Paid + $50 Budgets alarm before Day 13
Next: Day 6 — Consolidation 1. Recall drills Days 1–5, timed broken-server triage (service down / disk full / wrong permissions), portfolio review + FIRST RESUME BULLETS while work is fresh.

PROGRESS SNAPSHOT — Day 6 (2026-08-09)
Status: complete
Shipped:
  - Recall drill Days 1–5: 71% (below 80% bar — see re-drill list)
  - Timed triage (run untimed/guided; method taught mid-session): 3/3 faults diagnosed, fixed, VERIFIED
      • webapp.service 203/EXEC → missing execute bit; fixed + verified running w/ heartbeats
      • /srv/appdata 100% full → identified as null-byte file via `file`/`xxd` (NOT a real log), lsof clean, truncated; 0% verified
      • /srv/reports 700 root:root → rebuilt as 3770 analysts + default ACL; PAIRED tests: alice (member) writes ✓, bob (non-member) denied ✓
  - Repo README.md (first-impression artifact, selected-work table with control mappings)
  - resume-bullets-day06.md — 8 bullets tagged to target roles, each with an interview-defence line
Key methods banked:
  - 4-step debugging: observe → read the error → localize → fix ONE thing + verify
  - Real-incident additions: Step 0 "what changed?" (dpkg.log, journalctl -p err, deploy history) + broaden-before-narrow sweep (systemctl --failed, df -h, free -h, uptime, journalctl -p err)
  - systemd exit codes: 203/EXEC = can't execute ExecStart target (vs program ran and failed)
  - `file` says "data" not "ASCII text" → binary, nothing to archive
  - lsof BEFORE deleting large files; deleted-but-held-open ≠ space freed → truncate -s 0
  - df -i for inode exhaustion (disk "full" with free space)
  - Ticket closed ≠ incident closed: fix the cause (rotation), not just the symptom

  PROGRESS SNAPSHOT — Day 7 (2026-08-10)
Status: complete
Shipped:
  - CIDR worksheet, 14 questions: 11/14 first pass, 14/14 after corrections. Includes /22 and /20 (host bits spilling into third octet), reverse-sizing (N hosts → prefix), forward subnetting (/24 → 4× /26), and AWS's 5-address reservation (=251 usable in a /24).
  - Live tcpdump capture on loopback: password visible in plaintext query string; Authorization: Basic decoded with `base64 -d` to prove encoding ≠ encryption
  - Own-host network inventory: eth0 172.27.177.60/20, gateway 172.27.176.1, resolver 10.255.255.254, ARP table
  - SUMMARY.md — cumulative command reference + concepts, Days 1–7 (append each day going forward)
Concepts banked:
  - CIDR by derivation not memorization: host bits = 32−prefix; block size = 2^host bits; find the block CONTAINING the address
  - Split into N subnets = borrow log₂(N) bits; need N hosts = smallest 2^h ≥ N+2
  - lo is never the real network path; gateway ≠ resolver
  - ARP has no authentication → ARP spoofing = MITM with no exploit required
  - Base64 = encoding, not encryption; query-string creds leak more widely (logs, history, Referer) but neither is protected
  - TLS hides payload, not metadata: IPs, ports, SNI hostname, DNS, cert, traffic analysis all remain visible
  - python3 -m http.server serves CWD — exposed .git/ = full source history recoverable

Next: Day 8 — Networking II (DNS resolution path and record types, HTTP semantics, TLS handshake, certificates and chains). Lab: dig +trace, openssl s_client on a live handshake, build a tiny self-signed CA. Thread: TLS misconfiguration failure modes.

PROGRESS SNAPSHOT — Day 8 (2026-08-11)
Status: complete
Shipped:
  - DNS hierarchy walked manually (root → .com TLD → Cloudflare authoritative NS) after WSL2 blocked dig +trace
  - Live TLS chain analysis: 4-cert chain traced leaf→root; SAN inspected; 121 trusted root CAs enumerated
  - PROVEN: chain validation ≠ hostname validation (0 ok without -verify_hostname; 62 mismatch with it)
  - Private CA built end to end: self-signed root (subject==issuer), server CSR, signed cert with SAN extension
  - Trust model demonstrated: same cert → 21 (unable to verify) vs 0 (ok) with -CAfile; curl alert 46 on reject
  - day-08-networking-tls.md + day-08-ca-lab/ (public certs only) + SUMMARY.md Day-8 append
Concepts banked:
  - DNS is a security control: control resolution and TLS faithfully encrypts to the ATTACKER's server
  - TTL = how long a poisoned/stale record survives after the fix; lower TTLs BEFORE planned changes
  - Trust is not scoped: any of 121 CAs can issue for any domain → CAA records narrow it (same principle as per-repo GPG keys)
  - Wildcards match exactly one label
  - Old TLS versions = downgrade surface; removal is the only fix
  - Root CA self-signs; trust comes from being INSTALLED, not verified → also how corporate TLS interception works

Next: Day 9 — Nginx I (server blocks, reverse proxying, TLS termination). Lab: proxy an app over TLS with security headers (CSP, HSTS), server tokens hidden. Thread: the proxy as a security boundary. You'll reuse the CA you built today.