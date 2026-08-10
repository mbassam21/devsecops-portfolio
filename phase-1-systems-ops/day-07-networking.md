# Day 07 — Networking I

## Security thread
**What plaintext protocols leak.** Everything on a network is readable by anyone
positioned to see it unless it is encrypted — and "positioned" includes a
compromised host on the same segment, a malicious switch port, a rogue access
point, or another instance in the same cloud subnet. This day pairs the
*mechanism* that gets an attacker into the path (ARP has no authentication) with
the *payoff* once they are there (credentials in readable ASCII).

---

## 1. Layers as addressing + tools

Forget reciting seven OSI layers. What matters operationally: each layer has its
own addressing, its own tools, and its own failure mode.

| Layer | Addressing | Tools | Typical failure |
|---|---|---|---|
| **L2 Link** | MAC address | `ip link`, `ip neigh` | Can't reach anything on the local segment |
| **L3 Network** | IP address, routes | `ip addr`, `ip route`, `ping` | Wrong subnet, no route, no gateway |
| **L4 Transport** | Port, TCP/UDP | `ss`, `nc` | Service not listening, firewall drop |
| **L7 Application** | URLs, DNS names | `curl`, `dig`, `tcpdump -A` | DNS wrong, TLS mismatch, app error |

**Localizing a network fault = walking the layers bottom-up.** Do I have an IP?
Do I have a route? Can I reach the port? Does the app respond? Stop at the first
"no." This is Day 6's method applied to a network stack.

### Own-host inventory (this lab)
```
eth0     172.27.177.60/20        ← the routable interface
gateway  172.27.176.1            ← from "default via ... dev eth0"
resolver 10.255.255.254          ← from /etc/resolv.conf
ARP      172.27.176.1 → 00:15:5d:36:6f:94
```

Two distinctions worth stating plainly:

- **`lo` is always loopback, never the real network path.** WSL parks an extra
  address (`10.255.255.254/32`) on `lo`, which makes this easy to misread. The
  routable address lives on `eth0`.
- **The gateway and the resolver are different jobs.** The resolver turns names
  into IPs; the gateway is where packets go when the destination isn't on the
  local subnet. A **default route** means: *everything I don't otherwise know how
  to reach, send here.*

---

## 2. CIDR — derived, not memorized

An IPv4 address is **32 bits** in four 8-bit octets (hence 0–255 per octet, since
2⁸ = 256). The prefix says how many leading bits are the **network** portion; the
rest are **host** bits.

### The method — four moves
1. **host bits** = `32 − prefix`
2. **block size** = `2^(host bits)`
3. **find the block containing the address** — blocks start at multiples of the
   block size (0, 64, 128, 192 for a /26). *The address is often NOT on a
   boundary — this is the step that gets skipped.*
4. first address = **network** · last = **broadcast** · everything between =
   **usable** = `2^(host bits) − 2`

### Worked example — `10.0.4.0/26`
`32 − 26 = 6` host bits → `2⁶ = 64` per block → blocks at 0, 64, 128, 192 →
`.4` falls in **0–63** → network `10.0.4.0`, broadcast `10.0.4.63`,
usable `.1–.62` = **62 hosts**.

### Prefixes below /24
Host bits spill into the third octet. For `/20`: `32 − 20 = 12` host bits; the
last octet consumes 8, leaving **4 bits in the third octet** → blocks of
`2⁴ = 16` there.

`172.27.177.60/20` → third-octet blocks at 0, 16, …, **176**, 192 → `.177` is in
the 176 block → network `172.27.176.0`, broadcast `172.27.191.255`,
**4094 usable**.

*Verification:* `ip addr` reported `brd 172.27.191.255` and `ip route` showed
`172.27.176.0/20` — the machine confirms the arithmetic.

### Working backwards and forwards
- **Need N usable hosts** → smallest `2^h ≥ N+2` → prefix = `32 − h`.
  (6 hosts → 8 total → 2³ → **/29**)
- **Split into N subnets** → borrow `log₂(N)` bits.
  (4 subnets → +2 bits → `/24` becomes four `/26`s)

### Worksheet results (14 questions)

| # | CIDR | Network | Broadcast | Usable | Count |
|---|---|---|---|---|---|
| 1 | 192.168.1.0/24 | .1.0 | .1.255 | .1–.254 | 254 |
| 2 | 192.168.1.128/25 | .1.128 | .1.255 | .129–.254 | 126 |
| 3 | 172.16.5.32/27 | .5.32 | .5.63 | .33–.62 | 30 |
| 4 | 10.1.1.16/28 | .1.16 | .1.31 | .17–.30 | 14 |
| 5 | 192.168.10.200/26 | .10.192 | .10.255 | .193–.254 | 62 |
| 6 | 10.0.0.100/30 | .0.100 | .0.103 | .101–.102 | 2 |
| 7 | 172.20.8.0/22 | 172.20.8.0 | 172.20.11.255 | .8.1–.11.254 | 1022 |
| 8 | 192.168.4.77/28 | .4.64 | .4.79 | .65–.78 | 14 |
| 9 | 10.10.10.10/29 | .10.8 | .10.15 | .9–.14 | 6 |
| 14 | 172.17.0.0/16 | 172.17.0.0 | 172.17.255.255 | .0.1–.255.254 | 65534 |

- **#10** 6 usable hosts → **/29**
- **#11** `10.0.0.0/24` → `10.0.0.0/26`, `10.0.0.64/26`, `10.0.0.128/26`,
  `10.0.0.192/26` (only the last octet changes — the split stays inside the /24)
- **#12** **AWS reserves 5 addresses per subnet, not 2** → a `/24` VPC subnet
  gives **251** usable. This is the number to design against in Phase 2.
- **#13** `10.0.1.50` **is** inside `10.0.0.0/22` — 10 host bits, 2 in the third
  octet → blocks of 4 → range `10.0.0.0`–`10.0.3.255`

**Two traps recorded:**
- Last usable address ≠ usable count. For a `/24` both are 254 *by coincidence*;
  for a `/26` the range ends at `.254` but the count is 62.
- `/30` (2 usable) is the standard point-to-point link size.

---

## 3. ARP has no authentication → ARP spoofing

ARP answers "which MAC owns this IP?" on a local segment. A host broadcasts
*"who has 172.27.176.1?"* and the owner replies. **The protocol has no
authentication and no verification — the first answer wins, and hosts accept
unsolicited replies.**

So an attacker on the same segment announces *"the gateway is at MY MAC."* The
victim caches it, and every off-subnet packet flows through the attacker, who
forwards it onward so nothing appears broken while reading and modifying it in
transit. **No exploit is required — only presence on the segment and speaking the
protocol as designed.**

This is why "it's only internal traffic" is not a defence: internal segments are
exactly where ARP spoofing works.

---

## 4. Plaintext capture — credentials on the wire

Captured with `tcpdump` on loopback against a local HTTP server. All credentials
used were fabricated for the exercise and are redacted below (see §7 for why).

```bash
python3 -m http.server 8080 --bind 127.0.0.1 &
ss -tlnp | grep 8080                      # VERIFY it is listening before proceeding
sudo tcpdump -i lo -A -s 0 'tcp port 8080' -w /tmp/capture.pcap &

# request 1 — credentials in the query string
curl -s "http://127.0.0.1:8080/login?user=bassam&password=<REDACTED>" >/dev/null

# request 2 — HTTP Basic auth, sent as an Authorization header
curl -s -H 'Authorization: Basic <REDACTED_BASE64>' http://127.0.0.1:8080/ >/dev/null

sudo pkill tcpdump
sudo tcpdump -r /tmp/capture.pcap -A -n | grep -Ei 'password|authorization|GET'
```

**tcpdump flags:** `-i` interface · `-A` ASCII payload · `-s 0` full packet
(default truncates and loses the payload) · `-n` no DNS resolution · `-w` write ·
`-r` read · `'tcp port 8080'` BPF filter.

### What came back

```
GET /login?user=bassam&password=<REDACTED> HTTP/1.1
Host: 127.0.0.1:8080
User-Agent: curl/8.18.0
```

```
GET / HTTP/1.1
Authorization: Basic <REDACTED_BASE64>
```

Decoding the header value required no key and no cracking:

```bash
$ echo '<REDACTED_BASE64>' | base64 -d
<username>:<password>          # plaintext, one command, no secret required
```

### Findings
- The password is **readable ASCII** in the packet. No decoding, no cracking.
- `Authorization: Basic` is **base64 encoding, not encryption** — reversible with
  one command, no key. It exists to transmit special characters safely, not to
  protect anything.
- **Neither is protected on the wire.** Query-string credentials are *worse* in
  practice because URLs get logged in more places (proxy logs, browser history,
  server access logs, `Referer` headers), but on the wire both are equally
  exposed.
- Reading raw `tcpdump` output top-to-bottom is impractical — binary headers
  dominate. **Filter for what you're hunting.**

---

## 5. What TLS does and does not hide

> **TLS hides what you say, not who you say it to.**

Protected (inside the tunnel): request paths, headers, bodies, credentials,
cookies, tokens.

**Still visible to an in-path attacker:**
| Exposed | Why it must stay visible |
|---|---|
| Source + destination IPs | Required for routing |
| Port numbers | Required to reach the service |
| **SNI hostname** | Sent in the TLS handshake *before* encryption exists (Encrypted Client Hello is the fix, patchily deployed) |
| DNS queries | Resolved before the connection, unless DoH/DoT |
| Server certificate | Presented during the handshake |
| **Traffic analysis** | Packet timing, sizes, frequency — can reveal which page loaded, when a login happened, how much data moved |

Practical consequence: "we use TLS" does not satisfy every privacy or
confidentiality requirement, and an attacker who cannot read the traffic can
still map infrastructure by observing which hosts talk to which.

---

## 6. Operational caution learned

`python3 -m http.server` serves the **current working directory**. Started from
the repo root, it exposed `.git/`, `.gitignore`, every phase folder, and
`PROGRESS.md` over HTTP.

**An exposed `.git/` directory over HTTP lets an attacker reconstruct the entire
source history — including any secret ever committed, even if later removed.**
Never run a file server from a directory that was not deliberately chosen for it.

---

## 7. The secrets gate blocked this document — twice

Writing this artifact triggered the Day-5 gitleaks pre-commit hook on two
successive attempts. Both blocks were correct behaviour and both are worth
recording.

**Block 1** — the literal fabricated credentials (`RuleID: curl-auth-user`).
Fair catch: **credentials in documentation are exactly as exposed as credentials
in code.** gitleaks scans *content*, not file types — and documentation is where
credentials most often leak in practice, because people don't think of docs as
code.

**Block 2** — after replacing the values with the literal string
`REDACTED_PASSWORD`, the hook fired again. The `curl-auth-user` rule matches the
**shape** `-u <something>:<something>`, not the meaning of what's inside it. Any
two colon-separated strings after `-u` trip it — including environment variables
such as `"$USER:$PASS"`.

**Lesson: detection rules match patterns, not meaning.** This is the same
trade-off observed on Day 5 in the opposite direction — a raw AWS *secret* key
(40 base64 characters, structurally identical to any hash) passes *undetected*
because a rule broad enough to catch it would fire constantly. Rules tuned for
low false positives miss unprefixed secrets; rules tuned for coverage fire on
harmless text. Neither setting is "correct" — the operator has to know which
failure mode their tooling has.

**Resolution: remove the pattern, not bypass the control.**
`git commit --no-verify` would have worked and would have left no record. A
bypassed control trains the habit that eventually commits a real secret. The
legitimate alternatives, in order of preference:

1. **Restructure so the pattern doesn't occur** — here, the `-u user:pass` form
   was replaced with the equivalent `Authorization` header, which is also better
   documentation since the header is what the capture actually shows.
2. **Document an exception inline** — `# gitleaks:allow` on the specific line, or
   an entry in `.gitleaksignore`. The decision stays visible in the diff and
   reviewable forever.
3. **Never** `--no-verify`.

**Also removed:** the original base64 blob decoded back to the same fabricated
credential. Encoding is not redaction — leaving it would have reproduced this
day's own lesson as a mistake.

---

## SOC 2 mapping
- Network inventory (interfaces, routes, resolver, ARP table) as a known-good
  baseline → **CC7.1** (detecting unauthorized change)
- Demonstrated credential exposure over plaintext transport → **CC6.7**
  (protection of information in transmission); the remediation is TLS everywhere,
  including internal segments
- ARP spoofing as an unauthenticated MITM path → **CC6.6** (boundary protection);
  supports network segmentation and encrypted-transport requirements
- CIDR/subnet design competence underpins Phase 2 VPC segmentation → **CC6.6**
- Secrets gate enforced against this repository's own documentation, exception
  handled by remediation rather than bypass → **CC6.8**

## Artifacts
- `day-07-cidr-worksheet` — 14 subnetting questions with method shown
- `day-07-capture-notes` — annotated tcpdump excerpt showing plaintext credential
  exposure and base64 decode