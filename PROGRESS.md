PROGRESS SNAPSHOT — Day 1 (2026-07-27)
Status: complete
Shipped:
  - Dedicated WSL2 lab instance `devsecops90` provisioned (git 2.53.0, Docker CE via official signed repo + docker group, Claude Code 2.1.220); baselined & patched
  - GitHub repo github.com/mbassam21/devsecops-portfolio (SSH/keyless auth via ed25519)
  - Phase scaffold (phase-1..5, capstone, agents) + secrets-first .gitignore
  - phase-1-systems-ops/day-01-environment.md — attack-surface baseline + isolation decision + CC7.1 mapping (commit 4f6154a)
Gaps/issues:
  - AWS account is FREE plan → auto-closes ~6mo, restricts services, Org-join expires credits. ACTION: upgrade to Paid before Day 13 + set $50 Budgets alarm on arrival.
  - Empty phase folders not tracked (add .gitkeep — command provided) so remote shows full structure.
  - Doc polish: name the 10.255.255.254:53 WSL-DNS bind in summary; ss output truncated; verify Docker version reflects devsecops90.
  - Optional/parked: WSL networking mode + Passbolt exposure note on MAIN box (attack-surface completeness, CC7.1).
  - Day-1 interview questions awaiting answers.
Next: Day 2 — Users, groups, permissions (chmod/chown, umask, setuid/setgid/sticky, sudoers). Thread: least privilege at the OS layer (CC6.1).