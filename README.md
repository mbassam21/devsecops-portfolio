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
| [Hardened systemd service](phase-1-systems-ops/day-03-services.md) | Non-root service sandboxed from **8.3 "EXPOSED" → 1.9 "OK"** on `systemd-analyze security`, **with function preserved** | CC6.1 |
| [Production backup with proven restore](phase-1-systems-ops/day-05-automation.md) | Rotation, logging, archive verification, tested `trap ERR` failure path, and a **restore drill verified with `diff -r`** | A1.2, CC7.2 |
| [Secrets pre-commit gate](phase-1-systems-ops/day-05-automation.md) | Checksum-verified gitleaks install, fail-closed hook, blocked commits — plus documented analysis of **what the scanner does not catch** | CC6.8 |
| [Least-privilege shared storage](phase-1-systems-ops/day-02-permission.md) | setgid + sticky + default ACL, proven with positive **and negative** access tests | CC6.1 |
| [Safe bash refactor](phase-1-systems-ops/day-04-bash.md) | Deliberately unsafe script hardened to shellcheck-clean; guards for the three distinct failure classes (unquoted / unset / empty) | CC6.1, CC8.1 |
| [Attack-surface baseline](phase-1-systems-ops/day-01-environment.md) | Documented known-good listening-socket baseline as the precondition for drift detection | CC7.1 |

---

## Structure

```
phase-1-systems-ops/     Linux, permissions, systemd, bash, automation
phase-2-aws-terraform/   IAM, VPC, S3, Terraform, policy-as-code
phase-3-containers-k8s/  Docker, Kubernetes, supply chain, policy
phase-4-cicd/            GitHub Actions, OIDC, SAST/DAST, pipeline hardening
phase-5-secops-soc2/     Observability, incident response, SOC 2 evidence
agents/                  MCP-based automation agents
capstone/                Production microservices build with security gates
```

---

## Engineering practices

- **Evidence over assertion** — every claim in a day-doc is backed by terminal
  output, a measured before/after, or a verification command.
- **Failure paths are tested** — alerting that has never fired is an assumption,
  not a control.
- **Secrets hygiene** — secrets-first `.gitignore` plus a gitleaks pre-commit
  hook; full repository history scans clean.
- **Documented limitations** — where a control has gaps (local hooks are
  bypassable; scanners miss unprefixed secrets), the gap is stated rather than
  glossed over.

---

## Environment

Dedicated, disposable WSL2 Ubuntu 26.04 lab instance, isolated from any daily-driver
or client environment. All cloud work runs in a dedicated learning account.