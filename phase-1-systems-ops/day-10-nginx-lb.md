# Day 10 — Nginx II: Load Balancing, Health Checks & Rate Limiting

## Security thread
**Rate limiting as abuse defence.** This is the first control in the programme
that defends **availability** rather than confidentiality or integrity. It blunts
attacks that use *legitimate* requests in *illegitimate* volume — credential
stuffing, scraping, API abuse, application-layer DoS — the category firewalls and
signature-based tools struggle with, because no individual request is malformed.

---

## 1. Load balancing algorithms

An `upstream` block defines a **pool**; the algorithm decides distribution.

| Algorithm | Behaviour | When to use |
|---|---|---|
| **Round robin** (default) | Next server in turn, per request | Backends equal, request cost similar |
| **`least_conn`** | Fewest *active* connections wins | Request durations vary widely |
| **`ip_hash`** | Same client IP → same backend | Session stickiness — a **workaround**, not a design |

`ip_hash` breaks even distribution and fails when a backend dies. The correct
answer is stateless applications with shared session storage.

### Finding: `least_conn` does not distribute sequential traffic

Twelve sequential `curl` requests with `least_conn` **all went to BACKEND-1**.

Not a bug — the mechanism explains it. `least_conn` routes to whichever backend
has fewest *active* connections. With strictly serialised requests, every request
arrives when both backends hold **zero** connections. It is a tie every time, and
nginx breaks ties by choosing the first server in the pool.

**Proof by two tests:**

| Test | Config | Traffic | Result |
|---|---|---|---|
| A | `least_conn` | 10 **concurrent** (backgrounded `curl` + `wait`) | Alternated 1/2 ✓ |
| B | round robin | 6 **sequential** | Alternated 1/2 ✓ |

Same sequential traffic that pinned to one backend under `least_conn` distributes
cleanly under round robin — because round robin counts requests and ignores
connection state.

> **The algorithm changes behaviour in ways only visible under the right traffic
> pattern.** A team testing load balancing with sequential `curl` calls will
> conclude it is broken and "fix" the wrong thing.

*Also noted:* nginx's round robin is weighted and its counter carries across
requests, so short samples (6 requests) will not always alternate perfectly.
**Do not read a pattern into small-sample distribution noise.**

---

## 2. Passive health checks and failover

```nginx
upstream backend_pool {
    server 127.0.0.1:3000 max_fails=2 fail_timeout=10s;
    server 127.0.0.1:3001 max_fails=2 fail_timeout=10s;
}
```

`max_fails=N fail_timeout=Ts` = after N failures within T seconds, mark the
backend down and stop sending traffic for T seconds, then retry.

**These are *passive* checks** — nginx learns a backend is dead by failing a real
user's request. **The first user after a failure pays for the discovery.** Active
health checks (nginx proactively probing `/health`) are an nginx Plus feature; the
open-source alternatives are an external checker or a service mesh. Worth knowing
for interviews.

`proxy_next_upstream error timeout http_502 http_503 http_504` is what makes
failover *invisible* — a failed request is retried on the next backend rather than
returned as an error.

### Evidence
With BACKEND-2 killed, requests continued returning **200** — the live backend
absorbed the load and the user saw nothing. After restarting BACKEND-2 and waiting
out `fail_timeout`, it reappeared in rotation. **nginx retries failed backends
rather than blacklisting them permanently.**

### Test-design lesson
The failover test returned `200 ×7` then a `429`. The `429` was **rate limiting,
not failover** — confirmed in `error.log` (`limiting requests, excess: 5.970`).

> **When two controls can each produce a non-200, the test cannot attribute the
> result.** A clean failover measurement requires raising the rate limit or
> spacing the requests.

**Order of operations, confirmed by absence of evidence:** the error log contained
**no** connection-refused entries for the dead backend — only rate-limit errors.
Rate limiting is evaluated at the `location` level *before* `proxy_pass`, so a
throttled request never reaches an upstream at all. Cheap rejection precedes
expensive work.

---

## 3. Rate limiting

```nginx
limit_req_zone $binary_remote_addr zone=applimit:10m rate=10r/s;

location / {
    limit_req zone=applimit burst=5 nodelay;
    limit_req_status 429;
}
```

| Parameter | Meaning |
|---|---|
| `rate=10r/s` | Bucket **refill speed** — one token per ~100 ms |
| `burst=5` | Bucket **depth** — how many extra requests may queue |
| `nodelay` | Serve burst requests immediately rather than spacing them |
| `$binary_remote_addr` | IP stored as 4 bytes, not a string — 10 MB holds ~160,000 IPs |
| `limit_req_status 429` | Return "Too Many Requests" rather than the default 503 |

### Evidence — 20 rapid requests
```
200 200 200 200 200 200 200 429 429 429 200 429 429 429 429 200 429 429 429 429
sleep 3 → recovered: 200
```

The shape is the algorithm made visible:
- Opening run of **seven 200s** — burst allowance plus what `10r/s` permits in that window
- Then **429s** once the bucket empties
- **Isolated 200s scattered among the rejections** — the bucket refilling at
  ~1 token per 100 ms; one request slips through, the rest are rejected until the
  next token
- **`recovered: 200`** after a 3-second pause — full refill

**This sawtooth is the token bucket.** Rate limiting is not a binary gate; it is a
continuously refilling allowance.

### What rate limiting does and does not do
**Defends against:** credential stuffing, scraping, API abuse, application-layer
DoS — high-volume attacks made of individually valid requests.

**Does not defend against:**
- **Distributed sources** — it is **per-IP**; a botnet with thousands of addresses
  walks straight through
- **Volumetric floods** that saturate bandwidth before nginx sees a packet — these
  need upstream defence (CDN, WAF, AWS Shield — Day 71)

**Tuning is a real tradeoff:** too tight breaks legitimate users behind corporate
NAT (hundreds of people sharing one egress IP); too loose achieves nothing. The
limit must be defensible with a number, not chosen by feel.

---

## 4. `X-Forwarded-For`

```nginx
proxy_set_header X-Forwarded-For $remote_addr;   # OVERWRITE, not append
```

Day 9 used `$proxy_add_x_forwarded_for`, which **appends** the real IP to whatever
the client sent — so a client sending `X-Forwarded-For: 1.2.3.4` produces
`1.2.3.4, <real-ip>`, and an application reading the **first** value gets an
attacker-chosen address. That defeats per-IP rate limiting entirely (rotate the
forged value) and IP allowlisting (claim an internal address).

**Overwriting at the trusted edge discards client-supplied values.** The general
rule: a forwarded-IP header is trustworthy **only if every hop between the client
and the consumer is a proxy you control.**

---

## 5. Debug header — remove in production

```nginx
add_header X-Upstream $upstream_addr always;   # DEBUG ONLY
```
Confirmed working (`x-upstream: 127.0.0.1:3000`). Useful during development;
**discloses internal topology** and must be stripped before production — the same
reasoning as `server_tokens off`.

---

## SOC 2 mapping
- Load balancing + automatic failover, verified by killing a backend → **A1.1 /
  A1.2** (availability, capacity and recovery)
- Rate limiting as abuse and DoS defence → **CC6.6** (boundary protection),
  **CC7.2** (detecting anomalous activity — 429s in the error log are a signal)
- `X-Forwarded-For` overwritten at the trusted edge → **CC6.1** (preventing
  authorization decisions on attacker-controlled input)
- Internal topology disclosure removed before production → **CC6.6**

## Artifacts
- `day-10-nginx/lab.conf` — upstream pool, health checks, rate limiting
- `day-10-nginx/failover-evidence.txt` — status codes with a backend down
- `day-10-nginx/ratelimit-evidence.txt` — the 20-request 200/429 trace