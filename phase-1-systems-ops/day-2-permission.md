# Day 02 — Users, Groups & Permissions

## Security thread
Least privilege at the OS layer → **SOC 2 CC6.1** (logical access controls).
A compromised low-privilege account should be *contained* by permissions and
scoped sudo, not handed the whole box.

## Permission model (reference)
- 9 bits: owner/group/other × r/w/x. Numeric: r=4 w=2 x=1.
- On directories: r=list, w=add/delete/rename entries, x=traverse.
  KEY: deleting a file is a WRITE to its DIRECTORY, not the file.
- Special bits (leading digit): setuid=4 (run as owner), setgid=2
  (new files inherit dir's group), sticky=1 (delete only files you own).
- umask 022 → new files 644, new dirs 755. umask only REMOVES bits.

## Lab: multi-user shared directory (done correctly)
- Users alice, bob; shared group `engineering`.
- Dir: `chmod 3770` = setgid+sticky, `other:---` (non-members locked out).
- Default ACL: `setfacl -d -m g::rwx <dir>` so new files are group-writable
  automatically.

### Proven controls (with evidence)
- setgid: alice's new file had group `engineering`, not `alice`. ✓
- sticky: bob DENIED `rm` on alice's file ("Operation not permitted");
  file survived. ✓
- collaboration: bob successfully appended to alice's group-writable file. ✓

## War story: the "group-writable file that wasn't"
bob (confirmed in `engineering` via `id`) was repeatedly denied WRITE to a
file that `ls -l` showed as group `engineering`. Root cause after minimal-
repro bisection: **`>` truncates and RE-CREATES a file at the umask default
(644, group read-only)**, silently discarding an earlier `chmod 664`. It was
never a filesystem or group bug — the file was 644 at write time.
Debug path used: `id` in-process → `getfacl -n` (ACL clean, no mask) →
`lsattr` (no immutable flag) → root-write isolation → minimal reproduction
(strip all special bits, change one variable). The minimal test ended the
spiral in one shot.

### Lessons
- Per-file `chmod` is FRAGILE — `>` and many editors reset mode to umask
  default. Durable fix: directory **default ACLs** or a `002` umask.
- Debugging rule: when the model and the machine disagree, INSTRUMENT
  (id/getfacl/lsattr) and build a MINIMAL REPRODUCTION. Don't theorize.
- When ROOT is denied a basic op, the cause is BELOW permissions
  (immutable attr / MAC / filesystem) — not the mode bits.

## Lab: scoped sudo (admin-layer least privilege)
- Rule (`/etc/sudoers.d/bob-cron`, 440, validated with `visudo -c`):
  `bob ALL=(root) NOPASSWD: /usr/bin/systemctl restart cron`
- Proven: `restart cron` ALLOWED; `stop cron` DENIED; `cat /etc/shadow` DENIED.
- NOPASSWD applies ONLY to the exact listed command — scope is the control.
- Always edit via `visudo` (syntax-checks before save); never edit sudoers raw.

## CC6.1 mapping
Shared-dir least privilege + scoped sudo both evidence CC6.1: access is
granted at the minimum necessary level, and adjacent/broader actions are
provably denied.
