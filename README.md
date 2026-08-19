# DevSecOps Portfolio — Bassam Mohammed Zainudeen

Hands-on DevSecOps practice repository. Every entry is real work performed on a
dedicated lab environment, with terminal evidence, verification steps, and a
mapping to the SOC 2 Trust Services Criteria the artifact evidences.

**Principle applied throughout:** an artifact is not "done" when it runs — it is
done when its failure path has been tested and its correct behaviour verified.

---

## Selected work

| Artifact | What it demonstrates | Control |
|---|---|---|
| [**AI agent: MCP host auditor**](agents/health-monitor/) | Read-only MCP server exposing a single no-argument tool; root-owned observer behind a scoped `NOPASSWD` grant, unprivileged interpreter, findings mapped to CIS items. **Detected 3/3 seeded misconfigurations** — [demo transcript](agents/health-monitor/demo-transcript.md) | CC6.1, CC7.1 |
| [Hardening evidence pack](phase-1-systems-ops/day-11-hardening.md) | Default-deny firewall, fail2ban consuming live rate-limit events, 12-check CIS-subset audit — **plus a documented amendment correcting a false PASS the audit produced** | CC6.1, CC6.6, CC7.1 |
| [Hardened systemd service](phase-1-systems-ops/day-03-services.md) | Non-root service sandboxed from **8.3 "EXPOSED" → 1.9 "OK"** on `systemd-analyze security`, **with function preserved** | CC6.1 |
| [Production backup with proven restore](phase-1-systems-ops/day-05-automation.md) | Rotation, logging, archive verification, tested `trap ERR` failure path, and a **restore drill verified with `diff -r`** | A1.2, CC7.2 |
| [Secrets pre-commit gate](phase-1-systems-ops/day-05-automation.md) | Checksum-verified gitleaks install, fail-closed hook, blocked commits — plus documented analysis of **what the scanner does not catch** | CC6.8 |
| [nginx as a security boundary](phase-1-systems-ops/day-09-nginx.md) | TLS termination with a private CA, five security headers verified against the live response, version banner suppressed | CC6.6, CC6.7 |
| [Load balancing & rate limiting](phase-1-systems-ops/day-10-nginx-lb.md) | Passive health checks with proven failover; token-bucket rate limiting demonstrated and explained from observed refill behaviour | A1.1, CC6.6 |
| [DNS, TLS & a private CA](phase-1-systems-ops/day-08-networking-tls.md) | Certificate chain traced end to end; **chain validation vs hostname validation shown to be different checks** | CC6.7 |
| [Incident triage method](phase-1-systems-ops/day-06-consolidation.md) | Three seeded faults diagnosed and closed with **paired positive/negative verification**; documented four-step debugging method | CC7.3 |
| [Least-privilege shared storage](phase-1-systems-ops/day-02-permission.md) | setgid + sticky + default ACL, proven with positive **and negative** access tests | CC6.1 |
| [Safe bash refactor](phase-1-systems-ops/day-04-bash.md) | Deliberately unsafe script hardened to shellcheck-clean; guards for the three distinct failure classes (unquoted / unset / empty) | CC6.1, CC8.1 |
| [Packet capture & CIDR](phase-1-systems-ops/day-07-networking.md) | Credentials captured in plaintext from live traffic; `Authorization: Basic` decoded to show encoding is not encryption | CC6.7 |
| [Attack-surface baseline](phase-1-systems-ops/day-01-environment.md) | Documented known-good listening-socket baseline as the precondition for drift detection | CC7.1 |

---

## Structure

```
phase-1-systems-ops/     Linux, permissions, systemd, bash, networking, nginx, hardening
phase-2-aws-terraform/   IAM, VPC, S3, Terraform, policy-as-code
phase-3-containers-k8s/  Docker, Kubernetes, supply chain, policy
phase-4-cicd/            GitHub Actions, OIDC, SAST/DAST, pipeline hardening
phase-5-secops-soc2/     Observability, incident response, SOC 2 evidence
agents/                  MCP-based automation agents
capstone/                Production microservices build with security gates
career/                  Resume bullets with interview-defence lines
SUMMARY.md               Cumulative command & concept reference
```

---

## Engineering practices

- **Evidence over assertion** — every claim in a day-doc is backed by terminal
  output, a measured before/after, or a verification command.
- **Failure paths are tested** — alerting that has never fired is an assumption,
  not a control. A check that has only ever passed is unverified.
- **Test observable effect, not configuration text** — a config file records
  intent; a live response records behaviour. Where they can diverge, test the
  behaviour. ([why this rule exists](phase-1-systems-ops/day-11-hardening.md))
- **Secrets hygiene** — secrets-first `.gitignore` plus a gitleaks pre-commit
  hook; full repository history scans clean.
- **Documented limitations** — where a control has gaps (local hooks are
  bypassable; scanners miss unprefixed secrets; a firewall can be verified as
  loaded but not as blocking without a second host), the gap is stated rather
  than glossed over.
- **Corrections are published, not silently edited** — where a claim in this repo
  was later found to be wrong, an amendment records what was claimed, what was
  true, and why the error occurred.

---

## Environment

Dedicated, disposable WSL2 Ubuntu 26.04 lab instance, isolated from any
daily-driver or client environment. All cloud work runs in a dedicated learning
account.