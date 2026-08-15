#!/usr/bin/env bash
set -uo pipefail

pass=0; fail=0
chk() { # chk "description" "condition-command"
  if eval "$2" >/dev/null 2>&1; then
    printf "[PASS] %s\n" "$1"; pass=$((pass+1))
  else
    printf "[FAIL] %s\n" "$1"; fail=$((fail+1))
  fi
}

echo "=== CIS-subset audit: $(hostname) $(date -Is) ==="

chk "Firewall (ufw) is active"                    "sudo ufw status | grep -q '^Status: active'"
chk "Default deny incoming policy"                "sudo ufw status verbose | grep -q 'deny (incoming)'"
chk "fail2ban service is running"                 "systemctl is-active --quiet fail2ban"
chk "No accounts with empty passwords"            "[ -z \"\$(sudo awk -F: '(\$2==\"\") {print \$1}' /etc/shadow)\" ]"
chk "No world-writable files outside /tmp"        "[ -z \"\$(sudo find / -xdev -type f -perm -0002 -not -path '/proc/*' -not -path '/sys/*' 2>/dev/null | head -1)\" ]"
chk "No unowned SUID binaries in /home,/opt,/srv" "[ -z \"\$(sudo find /home /opt /srv -xdev -type f -perm -4000 2>/dev/null | head -1)\" ]"
chk "/etc/shadow is 640 or stricter"              "[ \"\$(stat -c %a /etc/shadow)\" -le 640 ]"
chk "/etc/passwd is not world-writable"           "[ -z \"\$(find /etc/passwd -perm -0002)\" ]"
chk "Root is the only UID 0 account"              "[ \"\$(awk -F: '(\$3==0){print \$1}' /etc/passwd | wc -l)\" -eq 1 ]"
chk "sudo requires authentication (no global NOPASSWD:ALL)" "! sudo grep -rq 'NOPASSWD:\s*ALL' /etc/sudoers /etc/sudoers.d/ 2>/dev/null"
chk "nginx hides version (server_tokens off)"     "sudo grep -rq 'server_tokens off' /etc/nginx/"
chk "Automatic security updates configured"       "[ -f /etc/apt/apt.conf.d/20auto-upgrades ]"

echo "---"
echo "PASS: $pass  FAIL: $fail  SCORE: $(( pass * 100 / (pass + fail) ))%"
