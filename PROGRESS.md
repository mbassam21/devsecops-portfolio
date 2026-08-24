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

PROGRESS SNAPSHOT — Day 9 (2026-08-12)
Status: complete
Shipped:
  - nginx reverse proxy on 8443, TLS terminated with the Day-8 private CA, backend on 127.0.0.1:3000
  - All 5 security headers verified (HSTS, nosniff, X-Frame-Options, CSP, Referrer-Policy); server_tokens off + proxy_hide_header Server → neither layer leaks a version; HTTP/8080 → 301
  - HTTP/2 negotiated; cert 644 / key 600 root-only; privilege separation observed (root master + 16 www-data workers)
  - CA installed into Windows trust store → clean padlock on the same previously-rejected certificate
Concepts banked:
  - Web server vs reverse proxy vs load balancer = three JOBS; nginx/Caddy are front doors, Tomcat is an application server
  - THE PADLOCK IS NOT A SAFETY INDICATOR — it means "signed by something this machine was told to trust." Same mechanism as corporate TLS interception, service meshes, CA-installing malware.
  - X-Forwarded-For is client-supplied and APPENDED to; only trustworthy if every hop is a proxy you control
  - The proxy does NOT protect against app-layer vulns, DoS, or backend compromise
  - Plaintext to backend: fine over loopback, a finding across any real network (ARP spoofing) → the mTLS argument
  - nginx -t before every reload; ExecStartPre success + ExecStart failure = valid config, unavailable resource
Environment finding:
  - The two WSL2 instances SHARE A NETWORK NAMESPACE. Port isolation does not exist between them (nginx on the main box held :80). Empty Process column in ss -tlnp = owner outside this namespace. Lab moved to 8080/8443.
Gaps/issues:
  - OPEN: remove `Bassam Lab Root CA` from the Windows trust store at end of Phase 1 (certlm.msc). A live signing capability on the daily-driver machine.
  - PARKED — 4 program days out: AWS FREE plan → upgrade to Paid + $50 Budgets alarm BEFORE Day 13.
Next: Day 10 — Nginx II (load balancing: round robin / least connections, health checks, caching basics, rate limiting). Lab: two backends behind nginx, kill one and observe failover, add rate limiting. Thread: rate limiting as abuse defence.

PROGRESS SNAPSHOT — Day 10 (2026-08-14)
Status: complete
Shipped:
  - Two backends behind nginx (upstream pool, max_fails=2 fail_timeout=10s, proxy_next_upstream)
  - PROVEN failover: BACKEND-2 killed, requests continued returning 200; recovery after fail_timeout confirmed
  - PROVEN rate limiting: 20-request burst → 200×7 then 429s with isolated 200s as the bucket refilled; recovered after 3s
  - Algorithm comparison: least_conn pinned to one backend under sequential traffic (tie at zero connections); alternated under concurrency; round robin alternated sequentially
  - X-Forwarded-For corrected to $remote_addr (overwrite, not append) — applying own Day-9 analysis
  - day-10-nginx-lb.md + lab.conf + evidence traces + SUMMARY Day-10 append
Concepts banked:
  - Open-source nginx health checks are PASSIVE: the first user after a failure pays for the discovery
  - Rate limiting is evaluated BEFORE proxy_pass (proven by absence of upstream errors in the log)
  - Token bucket made visible: rate = refill speed, burst = depth, nodelay = serve immediately
  - Rate limiting defends AVAILABILITY; per-IP so a botnet defeats it; volumetric floods need CDN/WAF/Shield
  - TEST DESIGN: when two controls can each produce a non-200, the test cannot attribute the result
  - Small-sample distribution noise ≠ a pattern
Recall this session: Q1 9/10, Q2 8/10, Q3 8/10 (~83%) — first time at/above the checkpoint bar, and these were the questions deferred from Day 9 fatigue.
Gaps/issues:
  - OPEN: remove `Bassam Lab Root CA` from Windows trust store at end of Phase 1 (certlm.msc)
  - PARKED — 3 program days out: AWS FREE plan → upgrade to Paid + $50 Budgets alarm BEFORE Day 13
Next: Day 11 — Hardening (CIS Ubuntu subset, sshd hardening, UFW/iptables, fail2ban, auditd intro). Ship: hardening evidence pack with before/after audit output. Thread: the whole day — CC6.1/CC6.6/CC7.1. THEN Day 12: Agent 1 (MCP server health monitor) + Checkpoint 1.

PROGRESS SNAPSHOT — Day 12 (2026-08-16)
Status: partial — Agent 1 COMPLETE, Checkpoint 1 NOT YET TAKEN
Shipped:
  - Agent 1 (MCP Server Health Monitor) built and wired: claude mcp list → ✔ Connected
  - Three-layer architecture: root-owned bash observer + scoped NOPASSWD sudoers + unprivileged Python interpreter
  - ACCEPTANCE MET: 3/3 seeded misconfigurations detected (rogue SUID, world-writable root file, blanket NOPASSWD:ALL), each mapped to its CIS item
  - Demo transcript: model called run_audit (did not shell out), re-ranked failures by realistic exploitability rather than severity label, surfaced an un-encoded second-order risk (writable parent dir → binary replacement), honoured scope_note
  - day-12-agent1-mcp.md + agents/health-monitor/ + SUMMARY Day-12 append
Concepts banked:
  - An MCP server is a FILE, not a daemon — spawned as a child process, stdio/JSON-RPC, no port, lifetime = session (verified with ps)
  - Tool-surface design IS least privilege: no run_command (that's a shell), no fix_finding in v1 (write ≠ read), no steerable arguments
  - PRINCIPLE: evidence from deterministic tooling, interpretation by the model — never the reverse
  - NOPASSWD safety depends on the target being IMMUTABLE to the grantee (root:root 755 = execute-not-modify)
  - Keep tool output dumb; attach meaning in code the model can't influence
  - subprocess list form, never shell=True; encode scope humility in the data structure
  - PEP 668 / venv discipline; pin SDK major versions (mcp 1.29.0 under a <2 pin)
Gaps/issues:
  - CHECKPOINT 1 OUTSTANDING: practical task + 5 interview questions + artifact audit + 15-min role-play interview. Take it rested — a checkpoint taken tired measures fatigue.
  - Recall Q1/Q2 this session ~7/10, 6/10: precision on "who picked the checks" and on separating filter-proven from ban-unproven
  - VERIFY seeded faults removed (commands above)
  - OPEN: remove `Bassam Lab Root CA` from Windows trust store at end of Phase 1 (certlm.msc)
  - BLOCKING FOR DAY 13: AWS account still on FREE plan → upgrade to Paid + set $50 Budgets alarm. Day 13 enables GuardDuty/Security Hub/Config on day one.
Next: CHECKPOINT 1, then Day 13 — AWS account foundations (requires the Paid upgrade first).

PROGRESS SNAPSHOT — Day 13 (2026-08-23)
Status: complete
Shipped:
  - Root secured: 2 MFA devices (iPhone passkey + Google Authenticator), both sign-in tested
  - Named IAM identity `devsecops90` with MFA + account alias; root retired from daily use
  - AWS CLI v2 installed UNSCAFFOLDED, region eu-central-1
  - GuardDuty enabled (detector confirmed)
  - AWS Config: own recorder, all resource types + global, recordingScope PAID, "recording": true, lastStatus SUCCESS
  - Security Hub CSPM: FSBP v1.0.0 + CIS AWS Foundations v1.2.0, both READY
  - $50/month Budgets alarm at 50/80/100% thresholds
  - day-13-account-setup.md + SUMMARY Day-13 append
Concepts banked:
  - Root differs from any admin because every OTHER identity can be restricted by policy; root cannot. Can't limit what it does → only lever is making it hard to get into.
  - Phishing-resistant MFA: a code doesn't know which site it's typed into; a passkey checks the domain and refuses. Nothing typed = nothing to relay.
  - A recovery path is only as strong as everything it depends on (MFA seed on Drive → AWS root now depends on Google account security; accepted, documented).
  - DETECTION BEFORE INFRASTRUCTURE — all three services only see forward.
  - Three-way split: GuardDuty = BEHAVIOUR, Config = STATE + HISTORY, Security Hub = STANDARD. Only Config answers questions about the past.
  - A benchmark's value is that you didn't pick the checks — closes the Day-11 "who picked the 12?" objection.
  - Configured ≠ working (delivery channel exists, has delivered nothing yet).
Assessment:
  - Recall (Day 12): Q1 half, Q2 circular, Q3 no mechanism — still reaching for outcome over mechanism
  - Interview Q1 WRONG (chose Security Hub for a question about July — Config is the only one with history), Q2 correct and well-stated, Q3 not understood until rephrased
  - Spine rep: STRUCTURE improved (parts counted, boundary delivered) but services INVERTED — called GuardDuty the compliance engine. Third service-description drift today. Anchor on the QUESTION each answers, not the name.
  - Cost-check judgment before enabling Security Hub: correct professional instinct, noted as such
  - Account ID redaction was inconsistent across pastes — make it uniform
Gaps/issues:
  - [ ] Config delivery to S3 still shows empty objects — re-run describe-delivery-channel-status, expect SUCCESS + timestamp
  - [ ] AdministratorAccess is a documented temporary exception → narrowed Days 14-15
  - [ ] Long-lived access key in ~/.aws/credentials (plaintext) → replaced by STS temporary credentials Day 15
  - [ ] CIS v1.2.0 dates from 2018; v3.0.0/v5.0.0 available — revisit at Day 30 findings review
  - [ ] GuardDuty + Security Hub trials expire ~Day 43 — review actual charges together
  - [ ] OPEN since Phase 1: remove `Bassam Lab Root CA` from Windows trust store (certlm.msc)
Next: Day 14 — IAM I. Policy JSON anatomy, evaluation logic (explicit deny always wins, implicit deny by default, permission boundaries as a cap), least privilege in practice. Lab: author and test a least-privilege policy, then prove the denied actions are actually denied.

PROGRESS SNAPSHOT — Day 14 (2026-08-25)
Status: complete
Shipped:
  - AdwenAssessorReadOnly customer-managed policy: allows security-configuration read across IAM/S3/EC2/CloudTrail/Config/GuardDuty/SecurityHub/KMS; explicitly DENIES all data-plane reads
  - assessor-test user with single attached policy, verified via list-attached-user-policies
  - simulate-principal-policy proof: 4 allowed, 3 explicitDeny, 2 implicitDeny — all three decision types demonstrated in one output
  - day-14-iam-policies.md + assessor-policy.json + simulate-results.txt + SUMMARY Day-14 append
Concepts banked:
  - Bouncer with three lists: explicit deny (beats everything) → explicit allow required (silence = no) → permission boundary (caps everything)
  - THE READ-ONLY TRAP: AWS naming doesn't distinguish reading CONFIG from reading DATA. GetObject/GetSecretValue/GetFunction/Decrypt all say "Get".
  - Wildcard rule: wildcard where the namespace is safe (iam:Get*), ENUMERATE where it isn't (never s3:Get*)
  - Implicit deny is a DEFAULT and is overridable; explicit deny is a RULE and is not. A deny statement is a guarantee that survives other people's decisions.
  - Identity- vs resource-based is about WHERE IT ATTACHES. Only resource-based can grant cross-account access (has a Principal field).
  - ACCT=$(aws sts get-caller-identity --query Account --output text) — keeps account IDs out of committed scripts
Assessment:
  - Recall: Q1 8/10, Q2 9/10 (mechanism stated as mechanism), Q3 6/10 (gave danger, not the "documented contradiction" reasoning)
  - Interview Q1 6/10 — right method, then jumped to "add an allow" which only works for implicit deny; missed that the deny may live in an SCP/boundary/resource policy
  - Interview Q2 7/10 — wildcard-grants-future-actions correct; invented iam:GetSessionToken (real one is sts:); stated the tradeoff backwards (it was accepted deliberately, not an oversight)
  - Interview Q3 4/10 — honestly flagged as a guess. Attached "permanent unoverridable blocking" (that's explicit deny) to resource-based policies.
  - Spine rep 7/10 — BEST STRUCTURE YET. Parts counted, claim direct, mechanism correct. Boundary was an evidence argument ("proves to an auditor") rather than where the control STOPS.
  - Pattern to keep working: boundary = where it fails/costs, not why it's good.
Gaps/issues:
  - [ ] Policy proven by SIMULATION only — configured vs working, again. Day 15 assume-role gives a clean way to test as another identity without long-lived keys.
  - [ ] MFA condition drafted, not applied (stretch)
  - [ ] Delete assessor-test user when Phase 2 IAM work concludes
  - [ ] Config delivery channel — still needs a SUCCESS check (carried from Day 13)
  - [ ] AdministratorAccess narrowing + long-lived key replacement — Day 15
Next: Day 15 — IAM II. STS assume-role, temporary credentials, cross-account access, MFA enforcement, Access Analyzer. Lab: build a deployer role, assume it via CLI, and use it to properly test the Day-14 assessor policy.