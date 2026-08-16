#!/usr/bin/env bash
# CIS-subset audit — emits id|status|evidence per line.
# Runs as root via a scoped NOPASSWD sudoers rule. READ-ONLY: no check mutates state.
set -uo pipefail

emit() { printf '%s|%s|%s\n' "$1" "$2" "$3"; }

chk() { # chk <id> <command> <evidence-command>
  if eval "$2" >/dev/null 2>&1; then
    emit "$1" "PASS" ""
  else
    emit "$1" "FAIL" "$(eval "$3" 2>/dev/null | head -5 | tr '\n' ';')"
  fi
}

chk "ufw-active"      "ufw status | grep -q '^Status: active'"                                    "ufw status | head -1"
chk "ufw-deny-in"     "ufw status verbose | grep -q 'deny (incoming)'"                            "ufw status verbose | grep Default"
chk "fail2ban-run"    "systemctl is-active --quiet fail2ban"                                      "systemctl is-active fail2ban"
chk "no-empty-pw"     "[ -z \"\$(awk -F: '(\$2==\"\"){print \$1}' /etc/shadow)\" ]"               "awk -F: '(\$2==\"\"){print \$1}' /etc/shadow"
chk "no-ww-files"     "[ -z \"\$(find / -xdev -type f -perm -0002 -not -path '/proc/*' -not -path '/sys/*' 2>/dev/null | head -1)\" ]" "find / -xdev -type f -perm -0002 -not -path '/proc/*' -not -path '/sys/*' 2>/dev/null"
chk "no-rogue-suid"   "[ -z \"\$(find /home /opt /srv -xdev -type f -perm -4000 2>/dev/null | head -1)\" ]" "find /home /opt /srv -xdev -type f -perm -4000 2>/dev/null"
chk "shadow-perms"    "[ \"\$(stat -c %a /etc/shadow)\" -le 640 ]"                                "stat -c '%a %n' /etc/shadow"
chk "single-uid0"     "[ \"\$(awk -F: '(\$3==0){print \$1}' /etc/passwd | wc -l)\" -eq 1 ]"       "awk -F: '(\$3==0){print \$1}' /etc/passwd"
chk "no-nopasswd-all" "! grep -rq 'NOPASSWD:[[:space:]]*ALL' /etc/sudoers /etc/sudoers.d/ 2>/dev/null" "grep -rl 'NOPASSWD:[[:space:]]*ALL' /etc/sudoers /etc/sudoers.d/ 2>/dev/null"
chk "nginx-tokens"    "grep -rq 'server_tokens off' /etc/nginx/"                                  "echo 'server_tokens off not found in /etc/nginx'"
chk "auto-updates"    "[ -f /etc/apt/apt.conf.d/20auto-upgrades ]"                                "echo '20auto-upgrades missing'"
