# Day 09 — Nginx I: Reverse Proxy & TLS Termination

## Security thread
**The proxy as a security boundary.** A reverse proxy collapses many exposed
services into one controlled front door: TLS terminates in a single place,
security policy applies uniformly regardless of what any individual application
forgets, and the application itself leaves the network entirely.

---

## 1. Web server vs reverse proxy vs load balancer

Three *jobs*, not three products — nginx performs all three depending on
configuration.

| Job | What it does |
|---|---|
| **Web server** | Serves files from disk (`/logo.png` → `/var/www/html/logo.png`) |
| **Reverse proxy** | Accepts a request, forwards it to a backend, returns the response. Client never talks to the backend |
| **Load balancer** | A reverse proxy with multiple backends + health checking (Day 10) |

*"Reverse"* because a **forward** proxy sits in front of **clients** (corporate
egress filtering); a **reverse** proxy sits in front of **servers**.

### Why the reverse proxy matters
1. **The backend leaves the network** — binds `127.0.0.1`, unreachable externally
2. **TLS terminates once** — the app never handles certificates, renewals, ciphers
3. **Policy applies uniformly** — headers, rate limits, size caps enforced centrally
4. **Backends become swappable** — change language, port, or count invisibly
5. **Static content never reaches the app** — nginx serves files; the app runtime
   only handles requests that need logic

### Product comparison
| | What it is | Layer |
|---|---|---|
| **nginx** | Web server + reverse proxy + LB (C) | Front door |
| **Caddy** | Same category (Go); **automatic Let's Encrypt** by default | Front door |
| **Tomcat** | **Java application server** (servlet container) | Backend — *runs* the app |

**Mental model:** something *runs your application code* (Tomcat, Gunicorn, Node,
Python); something else *sits in front managing the outside world* (nginx, Caddy).
They are complements, not alternatives. Conflating them is a common interview tell.

---

## 2. Privilege separation, observed

```bash
ps -eo user,comm | grep nginx
# root     nginx      ← master: binds ports <1024, reads the private key
# www-data nginx  ×16 ← workers: handle untrusted network input
```

Root **only** for the operations that genuinely require it, then drop to an
unprivileged user for everything touching the network. A compromised worker
yields `www-data`, not root — and cannot read the TLS private key. Identical
pattern to the Day-3 `healthmon` service, shipped by a web server running a large
share of the internet.

---

## 3. Incident: port 80 already in use

```
nginx: [emerg] bind() to 0.0.0.0:80 failed (98: Address already in use)
```

`ss -tlnp` in the lab instance showed the port **LISTEN** with an **empty Process
column** — the kernel could not attribute the socket to any process it could see.
That absence *was* the diagnosis: the listener lives outside this instance's
process namespace.

Confirmed from the other WSL instance: nginx, master PID 333 + 16 workers.

**Finding: the two WSL2 instances share a network namespace.** Filesystem and
process isolation hold; **port isolation does not**. A bind in one instance blocks
the other.

**Resolution:** run the lab on non-privileged ports (8080/8443) rather than
contending for 80/443. Identical concepts, no disruption to the other environment.

*Also noted:* `ExecStartPre=/usr/sbin/nginx -t` **succeeded** while `ExecStart`
failed — nginx distinguishes "your config is invalid" from "your valid config
asks for resources I cannot acquire." **Always `nginx -t` before reload;** a bad
reload takes the site down.

---

## 4. The reverse proxy configuration

```nginx
# HTTP → redirect only, never a data path
server {
    listen 8080;
    server_name lab.local localhost;
    server_tokens off;
    return 301 https://$host:8443$request_uri;
}

server {
    listen 8443 ssl;
    listen [::]:8443 ssl;
    http2 on;
    server_name lab.local localhost;

    ssl_certificate     /etc/nginx/certs/server.crt;
    ssl_certificate_key /etc/nginx/certs/server.key;
    ssl_protocols       TLSv1.2 TLSv1.3;      # no downgrade surface (Day 8)
    ssl_ciphers         HIGH:!aNULL:!MD5;
    ssl_session_cache   shared:SSL:10m;

    server_tokens off;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header Content-Security-Policy "default-src 'self'" always;
    add_header Referrer-Policy "no-referrer" always;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_hide_header Server;
    }
}
```

### Certificate file permissions
```
-rw-r--r-- root root server.crt    644 — public, sent to every client
-rw------- root root server.key    600 — root only
```
Anyone who reads the private key can impersonate this server to anything trusting
the CA. This is *why* the nginx master runs as root: it reads the key at startup,
then drops privileges for the workers.

### What each header prevents
| Header | Prevents |
|---|---|
| `server_tokens off` + `proxy_hide_header Server` | Version disclosure → CVE matching without probing |
| **HSTS** | SSL-stripping — downgrading the first HTTP request before the redirect |
| **`nosniff`** | Content-type guessing — an uploaded "text/plain" file executed as JS |
| **`X-Frame-Options: DENY`** | Clickjacking — invisible iframe over a fake button |
| **CSP `default-src 'self'`** | Most XSS — injected `<script src="evil.com">` will not execute |
| `always` | Ensures headers apply to **4xx/5xx** responses too |

### Verified result
```
HTTP/2 200
server: nginx                              ← no version
strict-transport-security: max-age=31536000; includeSubDomains
x-content-type-options: nosniff
x-frame-options: DENY
content-security-policy: default-src 'self'
referrer-policy: no-referrer
```
No Python `Server` header leaked through. HTTP/8080 returned `301`. Backend content
served correctly through the proxy. Without `--cacert`, curl rejected the
connection outright.

---

## 5. The padlock is not a safety indicator

The browser initially rejected the certificate. After exporting `ca.crt` and
installing it into the **Windows Trusted Root Certification Authorities** store,
the same certificate produced a clean padlock — Certificate Viewer showing
*Issued To: lab.local*, *Issued By: Bassam Lab Root CA*.

**Nothing about the certificate changed. No cryptography was defeated.** The
browser behaved correctly throughout; the trust store's definition of "trusted"
was redefined.

**This is precisely how corporate TLS interception works:** push a company root CA
to every managed endpoint, place a proxy in the path minting certificates on
demand, and every site shows a clean padlock while the proxy reads everything.
The same mechanism appears benignly in Kubernetes service meshes (internal CA
issuing mTLS certs to pods) and maliciously in malware that installs a root CA to
intercept banking sessions.

> **The padlock does not mean "safe." It means "signed by something this machine
> was told to trust."** Anyone who can write to a trust store controls what the
> padlock means.

**Open item:** remove the lab CA from the Windows trust store at the end of
Phase 1 — `certlm.msc` → Trusted Root Certification Authorities → Certificates →
`Bassam Lab Root CA` → Delete.

---

## 6. Boundary analysis — what this does and does not protect

### The `X-Forwarded-For` trust problem
`$proxy_add_x_forwarded_for` **appends** the real IP to whatever the client sent.
A client sending `X-Forwarded-For: 1.2.3.4` produces `1.2.3.4, <real-ip>` — so an
application reading the **first** value gets an attacker-chosen address. That
defeats IP-based rate limiting (rotate the fake value) and IP allowlisting (claim
an internal address).

**A forwarded-IP header is only trustworthy if every hop between the client and
the consumer is a proxy you control.** Either read the value your proxy appended
(last, not first), or overwrite the header entirely:
`proxy_set_header X-Forwarded-For $remote_addr`. A recurring bug behind CDNs and
load balancers.

### What the proxy does NOT protect against
- **Application-layer vulnerabilities** — SQLi, broken authN/authZ, IDOR, business
  logic flaws. The proxy forwards the request faithfully, payload included.
  *Transport security says nothing about application correctness.*
- **Denial of service** — nginx will proxy a flood until the backend falls over.
  Rate limiting helps (Day 10); volumetric attacks need upstream defence
  (CDN/WAF/Shield — Day 71).
- **Backend compromise and lateral movement** — the proxy controls the front door
  only.

### Plaintext from proxy to backend — acceptable or a finding?
**Acceptable** when both endpoints are on the same host over loopback (as here):
traffic never reaches a network interface, so observing it already requires root
on the box.

**A finding** the moment that hop crosses a real network — separate hosts, across
a VPC, or through any shared segment. Day 7's ARP spoofing means "internal"
networks are readable by anyone with presence on the segment. This is why
zero-trust architectures and service meshes encrypt **every** hop with mTLS rather
than assuming the internal network is safe.

> The auditor's question is always: *between these two points, who could be
> listening, and how do you know?*

---

## SOC 2 mapping
- TLS termination with modern protocols only, HTTP→HTTPS redirect → **CC6.7**
  (protection of information in transmission)
- Backend bound to loopback; proxy as sole ingress → **CC6.6** (boundary
  protection), **CC6.1** (least privilege at the network layer)
- Security headers applied uniformly at the edge → **CC6.6 / CC6.7**
- Version disclosure suppressed at both layers → **CC6.6** (reducing information
  available to an attacker)
- Private key restricted to root, workers unprivileged → **CC6.1**

## Artifacts
- `day-09-nginx/lab.conf` — the reverse proxy configuration
- `day-09-nginx/headers-verified.txt` — curl output evidencing all headers
- CA and server certificates from Day 8 (`day-08-ca-lab/`) — **keys not committed**