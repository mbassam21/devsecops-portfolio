#!/usr/bin/env python3
"""Agent 1 — Server Health Monitor (MCP server).

Design constraints, deliberate:
  * ONE tool, `run_audit`, taking NO arguments — nothing an attacker can steer.
  * READ-ONLY. This server cannot change host state.
  * Evidence comes from a deterministic root-owned bash script; this process
    runs unprivileged and only adds metadata and structure.
"""

import platform
import subprocess
from datetime import datetime, timezone

from mcp.server.fastmcp import FastMCP
from pydantic import BaseModel

AUDIT_SCRIPT = "/usr/local/bin/cis-audit-json.sh"

# The bash script emits opaque check IDs. All meaning lives here, in code the
# model never influences.
CHECK_META: dict[str, dict[str, str]] = {
    "ufw-active": dict(
        cis="3.5.1.1", severity="high", control="CC6.6",
        title="Host firewall (ufw) is enabled",
        rationale="Without a host firewall, every listening service is reachable from any network the host can see.",
        remediation="sudo ufw --force enable"),
    "ufw-deny-in": dict(
        cis="3.5.1.2", severity="high", control="CC6.6",
        title="Default deny policy for inbound traffic",
        rationale="A default-allow firewall permits anything not explicitly denied; new services are exposed the moment they start.",
        remediation="sudo ufw default deny incoming"),
    "fail2ban-run": dict(
        cis="4.2.x", severity="medium", control="CC7.3",
        title="fail2ban is running",
        rationale="Without dynamic blocking, repeated abuse is throttled per-request but never escalated to a network-level block.",
        remediation="sudo systemctl enable --now fail2ban"),
    "no-empty-pw": dict(
        cis="5.4.2", severity="critical", control="CC6.1",
        title="No accounts with empty passwords",
        rationale="An account with no password can be logged into by anyone who can reach an authentication surface.",
        remediation="sudo passwd -l <user>  # or set a password / remove the account"),
    "no-ww-files": dict(
        cis="6.1.9", severity="high", control="CC6.1",
        title="No world-writable files outside /tmp",
        rationale="A world-writable file can be replaced by any user. If root ever executes it (cron, service, sourced script) that is direct privilege escalation.",
        remediation="chmod o-w <file>, or justify and document the exception"),
    "no-rogue-suid": dict(
        cis="6.1.13", severity="high", control="CC6.1",
        title="No unowned SUID binaries in /home, /opt, /srv",
        rationale="A SUID binary runs as its owner regardless of caller. One owned by no package is unaudited — any flaw in it is a direct path to that owner's privileges.",
        remediation="Remove the file, or attribute it to a package and document why SUID is required"),
    "shadow-perms": dict(
        cis="6.1.3", severity="high", control="CC6.1",
        title="/etc/shadow permissions are 640 or stricter",
        rationale="/etc/shadow holds password hashes. Readable hashes can be cracked offline with no rate limiting and no logging.",
        remediation="sudo chmod 640 /etc/shadow"),
    "single-uid0": dict(
        cis="5.5.3", severity="critical", control="CC6.1",
        title="root is the only UID 0 account",
        rationale="A second UID 0 account is root-equivalent but hides in plain sight — a classic persistence backdoor.",
        remediation="Investigate and remove the additional UID 0 account"),
    "no-nopasswd-all": dict(
        cis="5.3.4", severity="high", control="CC6.1",
        title="No blanket NOPASSWD:ALL in sudoers",
        rationale="Passwordless root for every command removes the re-authentication barrier; a stolen session becomes silent, instant root.",
        remediation="Scope sudo rules to the explicit commands required"),
    "nginx-tokens": dict(
        cis="n/a", severity="low", control="CC6.6",
        title="nginx suppresses its version banner",
        rationale="Version disclosure lets an attacker match the host to known CVEs without probing.",
        remediation="Add 'server_tokens off;' to the nginx configuration"),
    "auto-updates": dict(
        cis="1.9", severity="medium", control="CC6.8",
        title="Automatic security updates are configured",
        rationale="Unpatched known vulnerabilities remain the most common initial access vector.",
        remediation="sudo dpkg-reconfigure -plow unattended-upgrades"),
}


class Finding(BaseModel):
    id: str
    cis_item: str
    title: str
    status: str
    severity: str
    evidence: str
    rationale: str
    remediation: str
    soc2_control: str


class AuditReport(BaseModel):
    host: str
    timestamp: str
    checks_run: int
    passed: int
    failed: int
    score_percent: int
    scope_note: str
    findings: list[Finding]


mcp = FastMCP("server-health-monitor")


@mcp.tool()
def run_audit() -> AuditReport:
    """Run a read-only CIS-subset security audit of this host.

    Executes a fixed set of configuration checks (firewall, account hygiene,
    file permissions, SUID inventory, sudo scoping, patch currency) and returns
    every check with its status, severity, rationale and remediation.

    This tool observes only. It cannot modify the host. It takes no arguments.
    """
    proc = subprocess.run(
        ["sudo", "-n", AUDIT_SCRIPT],   # list form, no shell — no injection surface
        capture_output=True, text=True, timeout=120, check=False,
    )

    if proc.returncode != 0 and not proc.stdout.strip():
        raise RuntimeError(
            f"audit script failed (exit {proc.returncode}): {proc.stderr.strip()[:300]}"
        )

    findings: list[Finding] = []
    for line in proc.stdout.strip().splitlines():
        parts = line.split("|")
        if len(parts) != 3:
            continue
        check_id, status, evidence = parts
        meta = CHECK_META.get(check_id, dict(
            cis="unknown", severity="unknown", control="unknown",
            title=check_id, rationale="No metadata registered for this check.",
            remediation="Review manually."))
        findings.append(Finding(
            id=check_id,
            cis_item=meta["cis"],
            title=meta["title"],
            status=status,
            severity=meta["severity"] if status == "FAIL" else "info",
            evidence=evidence.strip(),
            rationale=meta["rationale"],
            remediation=meta["remediation"],
            soc2_control=meta["control"],
        ))

    passed = sum(1 for f in findings if f.status == "PASS")
    failed = sum(1 for f in findings if f.status == "FAIL")
    total = passed + failed

    return AuditReport(
        host=platform.node(),
        timestamp=datetime.now(timezone.utc).isoformat(),
        checks_run=total,
        passed=passed,
        failed=failed,
        score_percent=round(passed * 100 / total) if total else 0,
        scope_note=(
            "SUBSET of the CIS Ubuntu benchmark, not full compliance. "
            "A perfect score means this host passed the checks that were selected, "
            "not that it is secure."
        ),
        findings=findings,
    )


if __name__ == "__main__":
    mcp.run()   # stdio transport
