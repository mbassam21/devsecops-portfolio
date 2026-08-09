# Resume Bullets — Drafted Day 6 (Phase 1, Days 1–6)

Drafted while the work was fresh. Each bullet maps to a real artifact in
`devsecops-portfolio` and can be defended in an interview.

**Bullet formula used:** *action verb → specific technical work → measurable
result or verification.* 

---

## Primary bullets (use these first)

**1. Service hardening — measurable**
> Hardened a Linux systemd service from an 8.3 "EXPOSED" to a 1.9 "OK"
> `systemd-analyze security` exposure score while preserving functionality,
> applying seccomp syscall allow-listing, full capability dropping, network
> namespace isolation, and non-root execution under a dedicated `nologin`
> system account.

*Roles: DevSecOps Engineer, Platform Engineer, Cloud Security Engineer*
*Interview defence: NoNewPrivileges neutralises setuid escalation; PrivateNetwork
blocks pivot/exfil; CapabilityBoundingSet= drops all ~40 root capabilities.*

**2. Backup assurance — the differentiator**
> Built a production backup pipeline with retention rotation, structured
> logging, and `trap ERR` failure alerting; validated recoverability through a
> restore drill verified with recursive diff against source — distinguishing
> scheduling, execution, integrity, and recoverability as separate evidence
> claims.

*Roles: SRE, Platform Engineer, Cloud Infrastructure Engineer*
*Interview defence: `tar | gzip` exits 0 even when tar dies — pipefail +
verification + a tested alert path are what make a backup a recovery capability
rather than a compliance artifact.*

**3. Secrets prevention — with honest limits**
> Deployed a checksum-verified, fail-closed gitleaks pre-commit gate blocking
> credential commits, and documented its detection boundary (unprefixed secrets
> such as raw AWS secret keys evade signature-based rules), recommending
> CI-side enforcement to close the bypass and portability gaps.

*Roles: DevSecOps Engineer, Cloud Security Engineer*
*Interview defence: two independent gaps — detection (needs contextual rules)
and enforcement (`--no-verify` bypass, hooks aren't cloned) — need two different
fixes.*

**4. Least-privilege access design**
> Designed multi-user shared storage using setgid group inheritance, sticky-bit
> delete protection, and default ACLs, verified with paired positive and
> negative access tests proving authorised members gained access and
> non-members were denied.

*Roles: Cloud Security Engineer, Platform Engineer*
*Interview defence: deletion is governed by directory permissions, not file
permissions; setgid grants group ownership but not group write — a distinction
that silently breaks collaboration.*

---

## Supporting bullets

**5. Secure scripting**
> Refactored unsafe shell automation to shellcheck-clean, guarding the three
> distinct failure classes — unquoted expansion (word-splitting/globbing),
> unset variables, and set-but-empty variables — each requiring a different
> mitigation.

**6. Incident triage**
> Diagnosed and remediated concurrent production-style faults (service exec
> failure, filesystem exhaustion, access misconfiguration) using a structured
> observe → localise → remediate → verify methodology, identifying root cause
> from exit codes and file signatures rather than symptom-matching.

**7. Configuration baselining**
> Established and version-controlled a known-good listening-socket baseline as
> the precondition for change detection, mapped to CC7.1.

**8. Scheduled-execution audit**
> Inventoried all scheduled-execution paths across cron directories, user
> crontabs, and systemd timers, attributing every entry to an owning package —
> a persistence-detection technique for post-compromise assessment.

---

## Framing notes

- Lead with **#1 and #2** — both carry measurable, verifiable outcomes, which is
  rare in junior-to-mid portfolios.
- **#3's documented limitation is a feature, not a weakness.** Most candidates
  claim a tool solved a problem; stating what it does *not* catch signals
  genuine understanding and reads as senior.
- For **Adwen**, bullets 1, 3, 4, and 8 map directly to scoped service offerings:
  service hardening review, secrets-exposure assessment, access-control review,
  and persistence/scheduled-task audit.
- Revisit and re-rank at each consolidation day (Days 12, 18, 24, 35, 55, 68).