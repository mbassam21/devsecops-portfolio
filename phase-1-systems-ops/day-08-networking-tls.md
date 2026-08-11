# Day 08 — Networking II: DNS, HTTP, TLS & Certificates

## Security thread
**TLS misconfiguration failure modes.** HTTPS security depends on certificate
validation, and certificate validation depends on DNS being correct. If an
attacker controls what a name resolves to, TLS still works perfectly — it
faithfully encrypts your traffic to *the attacker's* server, padlock and all.
Every component does exactly what it was designed to do. DNS is therefore a
security control, not plumbing.

---

## 1. DNS — the resolution path

A single lookup for `example.com` traverses four levels:

1. **Stub resolver** (libc / systemd-resolved) on the local machine
2. **Recursive resolver** from `/etc/resolv.conf` — does the walking, caches results
3. **Root servers** (`.`) — don't know the answer, refer to the TLD
4. **TLD servers** (`.com`) — don't know the answer, refer to the authoritative NS
5. **Authoritative nameservers** — hold the actual records and answer

### Walked manually (own output)
```bash
dig @1.1.1.1 example.com +noall +answer
#  example.com. 167 IN A 104.20.23.154
#  example.com. 167 IN A 172.66.147.243

dig @1.1.1.1 NS com +short
#  a.gtld-servers.net. … m.gtld-servers.net.   (13 .com TLD servers)

dig @1.1.1.1 NS example.com +short
#  hera.ns.cloudflare.com.
#  elliott.ns.cloudflare.com.
```

**Three referrals, four levels, for one lookup.** This is why caching matters —
without it every request replays the entire walk.

**Recon value:** two queries revealed the hosting provider and CDN (Cloudflare
nameservers, Cloudflare IP ranges). TXT records commonly expose SPF mail
infrastructure, DKIM selectors, and SaaS domain-verification tokens naming a
company's vendors. **DNS enumeration is step one of every assessment.**

### Record types that matter operationally
| Type | Holds | Why it matters |
|---|---|---|
| A / AAAA | IPv4 / IPv6 address | Basic name→IP mapping |
| **CNAME** | Alias to another name | **Dangling CNAME = subdomain takeover** |
| NS | Authoritative nameservers | Who controls the zone |
| MX | Mail servers | Mail routing |
| TXT | Arbitrary text | SPF/DKIM/verification — leaks infrastructure |
| SOA | Zone metadata | Serial, refresh timers |
| **CAA** | **Which CAs may issue certs for this domain** | Narrows CA blast radius |
| PTR | Reverse IP→name | Mail reputation, reverse lookups |

### TTL is a security parameter
TTL = how many seconds a resolver may cache an answer before re-querying.

- **Long TTL (86400):** a poisoned or compromised record persists in caches
  worldwide for a full day *after* you fix it. You cannot force the internet to
  forget. It also slows legitimate emergency failover and post-breach IP rotation.
- **Short TTL (60):** fast recovery, higher query volume.
- **Runbook practice:** lower TTLs *before* a planned change (drop to 60s a day
  ahead, change, raise after). A TTL already cached cannot be retroactively
  shortened.

### Cross-resolver comparison as a diagnostic
`dig example.com` and `dig @8.8.8.8 example.com` returned identical answers — the
healthy case. Divergence can be benign (geo load balancing, CDN edge selection,
anycast) or serious (**DNS hijacking, cache poisoning, tampered resolver**). The
diagnostic move is to query the **authoritative** nameserver directly — it is the
source of truth, and any resolver disagreeing with it is stale or lying.

### Environment finding
WSL2's DNS proxy (`10.255.255.254`) silently times out on iterative queries —
`dig +trace` and `dig +trace +tcp` both failed — while normal recursive lookups
succeed. Workaround: `dig @1.1.1.1` for anything beyond simple resolution. *A
resolver that answers some query types and not others is itself worth noting in
an assessment.*

---

## 2. TLS handshake and certificate chains

### The chain (live, example.com)
```
0 s:CN=example.com
  i:Cloudflare TLS Issuing ECC CA 3
1 s:Cloudflare TLS Issuing ECC CA 3
  i:SSL.com TLS Transit ECC CA R2
2 s:SSL.com TLS Transit ECC CA R2
  i:SSL.com TLS ECC Root CA 2022
3 s:SSL.com TLS ECC Root CA 2022
  i:AAA Certificate Services (Comodo)
```

Each certificate's **issuer** matches the next certificate's **subject** — that
is the chain. Verification walks upward until it reaches a certificate already in
the local trust store.

### Where trust actually terminates
```bash
grep -c "BEGIN CERTIFICATE" /etc/ssl/certs/ca-certificates.crt   # → 121
```
**121 organisations** are trusted by this machine to vouch for *any* domain on
the internet. **Trust is not scoped** — any one of them can issue a technically
valid certificate for any site. A single compromised or coerced CA breaks
everything (DigiNotar, 2011). **CAA records** narrow this: a domain owner declares
which CAs may issue for it. Same *scope of trust* principle as per-repo GPG keys
(Day 3).

### SAN, not CN
```
X509v3 Subject Alternative Name: DNS:example.com, DNS:*.example.com
```
Modern clients check **subjectAltName**; the legacy `CN` field is deprecated.
**Wildcards match exactly one label** — `*.example.org` covers
`wrong.example.org` but **not** `a.b.example.org` and **not** bare `example.org`.
A frequent production surprise for teams who buy a wildcard and find
`api.staging.example.com` uncovered.

### CRITICAL: chain validation ≠ hostname validation
```bash
# chain valid, hostname NOT checked
openssl s_client -connect example.com:443 -servername example.org
#  → Verify return code: 0 (ok)

# hostname enforced — both fail correctly
openssl s_client ... -verify_hostname evil.example.net    # → 62 (hostname mismatch)
openssl s_client ... -verify_hostname a.b.example.org     # → 62 (hostname mismatch)
```
**`Verify return code: 0 (ok)` means only that the signature chain is sound.** It
says nothing about whether the certificate is for the host you intended.

**This is an expensive, recurring bug class.** Applications that validate the
chain but skip hostname verification will accept *any* valid certificate from
*any* of the 121 CAs — so an attacker holding a legitimate certificate for a
domain they own can MITM the connection while the application sees a perfectly
valid chain. It has shipped in payment libraries, mobile apps, and internal
service-to-service calls. **Two separate checks; omitting the second fails
silently.**

### Protocol downgrade
```
openssl s_client -connect example.com:443 -tls1_1
→ error:0A0000BF: no protocols available
```
The local OpenSSL refused to *attempt* TLS 1.1 (disabled at build/security level).
Refusing old versions is a control, not housekeeping: TLS 1.0/1.1 depend on broken
primitives (SHA-1, RC4, CBC constructions — BEAST, POODLE), and a server that
*accepts* them lets an attacker force a **downgrade** to the weakest mutually
supported version regardless of what modern clients prefer. **Supporting an old
protocol makes it reachable to an attacker.** Removal is the only fix; also a
PCI-DSS requirement and a standard audit finding.

---

## 3. Lab — build a private CA

```bash
# CA private key — the most sensitive file in any PKI
openssl genrsa -out ca.key 4096 && chmod 400 ca.key

# self-signed root
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 \
  -subj "/C=DE/O=Bassam Lab/CN=Bassam Lab Root CA" -out ca.crt
```
```
subject=C=DE, O=Bassam Lab, CN=Bassam Lab Root CA
issuer =C=DE, O=Bassam Lab, CN=Bassam Lab Root CA
```
**Subject and issuer are identical — that is what "root" means.** It vouches for
itself; trust comes from being *installed*, never from being *verified*.

```bash
# server key + CSR, then sign it with the CA
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -subj "/C=DE/O=Bassam Lab/CN=lab.local"
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 365 -sha256 -extfile server.ext
```
`server.ext` supplies the SAN (modern clients ignore CN):
```
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = lab.local
DNS.2 = localhost
IP.1  = 127.0.0.1
```
Result:
```
subject=C=DE, O=Bassam Lab, CN=lab.local
issuer =C=DE, O=Bassam Lab, CN=Bassam Lab Root CA
X509v3 Subject Alternative Name: DNS:lab.local, DNS:localhost, IP Address:127.0.0.1
```

### The trust model in two commands
```bash
openssl s_server -accept 8443 -cert server.crt -key server.key -www &

# A — client does not know the CA
openssl s_client -connect localhost:8443
#  → Verify return code: 21 (unable to verify the first certificate)

# B — client explicitly trusts the CA
openssl s_client -connect localhost:8443 -CAfile ca.crt
#  → Verify return code: 0 (ok)
```
curl agreed: without `--cacert` the connection produced
`tls alert certificate unknown` (SSL alert 46) — the *client* rejecting the
server on the wire.

**The certificate is cryptographically identical in both tests.** The only
variable is whether the client holds the CA. That is the entire trust model —
and exactly how corporate TLS interception works: install the company CA on every
endpoint, and the proxy can mint certificates for any site those endpoints will
accept without warning.

---

## 4. TLS misconfiguration failure modes (summary)

| Failure | Consequence | Detection |
|---|---|---|
| Expired certificate | Total outage; #1 cause of TLS incidents | Monitor `notAfter`, alert 30 days out |
| Hostname not in SAN | Client rejects; or silently accepted if app skips hostname check | `-verify_hostname` |
| Chain validated, hostname not | **MITM with a valid cert** | Code review; test with a mismatched host |
| Incomplete chain served | Fails on clients lacking the intermediate | `-showcerts`, verify from a clean host |
| Old protocol versions enabled | Downgrade attacks | `-tls1_1`, `-tls1` probes |
| Wildcard depth misunderstood | `a.b.example.com` uncovered | Read the SAN carefully |
| No CAA record | Any of 121 CAs may issue for the domain | `dig CAA <domain>` |
| Long TTL during incident | Poisoned/stale record persists after the fix | Lower TTL before planned changes |

---

## SOC 2 mapping
- TLS enforcement, certificate validity and chain integrity → **CC6.7**
  (protection of information in transmission)
- CAA records and CA scope limitation → **CC6.1** (authorization — restricting who
  may issue credentials for the domain)
- Certificate expiry monitoring and TTL change procedure → **CC7.2 / A1.2**
  (monitoring and availability)
- DNS/resolver integrity as a precondition for transport security → **CC6.6**
  (boundary protection)

## Artifacts
- `day-08-ca-lab/` — private CA (`ca.crt`), signed server certificate
  (`server.crt`), SAN extension file. **Private keys are NOT committed.**
- `day-08-dns-tls-cheatsheet.md` — `dig` and `openssl s_client` command reference