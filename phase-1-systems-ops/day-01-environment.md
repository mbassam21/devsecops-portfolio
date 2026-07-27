# Day 01 — Environment & Attack-Surface Baseline

## Lab environment
- Host: WSL2 on Windows, Intel Core Ultra 7 255H, 32 GB (15 GiB to Linux)
- Distro: Ubuntu 26.04 LTS (Resolute Raccoon), dedicated instance `devsecops90`
- Tooling: Docker 29.6.2, Git 2.53.0, Claude Code 2.1.220, VS Code
- Isolation decision: separate WSL2 instance so destructive labs never touch my
  daily-driver environment (blast-radius / environment isolation).

## Attack-surface baseline (known-good state)
Listening sockets on `devsecops90` (from `sudo ss -tulnp`):
- 127.0.0.1 / ::1 only: systemd-resolve (53), chronyd (323), VS Code server (39443)
- No wildcard (0.0.0.0 / ::) binds — no externally reachable services.

Netid     State      Recv-Q     Send-Q           Local Address:Port            Peer Address:Port     Process                                                                                              
udp       UNCONN     0          0                   127.0.0.54:53                   0.0.0.0:*         users:(("systemd-resolve",pid=81,fd=18))                                                            
udp       UNCONN     0          0                127.0.0.53%lo:53                   0.0.0.0:*         users:(("systemd-resolve",pid=81,fd=16))                                                            
udp       UNCONN     0          0               10.255.255.254:53                   0.0.0.0:*                                                                                                             
udp       UNCONN     0          0                    127.0.0.1:323                  0.0.0.0:*         users:(("chronyd",pid=230,fd=4))                                                                    
udp       UNCONN     0          0                    127.0.0.1:323                  0.0.0.0:*                                                                                                             
udp       UNCONN     0          0                        [::1]:323                     [::]:*                                                                                                             
udp       UNCONN     0          0                        [::1]:323                     [::]:*         users:(("chronyd",pid=230,fd=5))                                                                    
tcp       LISTEN     0          4096                127.0.0.54:53                   0.0.0.0:*         users:(("systemd-resolve",pid=81,fd=19))                                                            
tcp       LISTEN     0          511                  127.0.0.1:39443                0.0.0.0:*         users:(("MainThread",pid=627,fd=22))                                                                
tcp       LISTEN     0          4096             127.0.0.53%lo:53                   0.0.0.0:*         users:(("systemd-resolve",pid=81,fd=17))                                                            
tcp       LISTEN     0          1000            10.255.255.254:53                   0.0.0.0:*   

Observation: my primary WSL box exposed sshd + Caddy(80/443) + MySQL + Postfix —
documented as a real-world reason to baseline before you can detect change.

## AWS learning account
- Fresh dedicated account, empty, no Adwen/client history. Plan type: Free.
- Budgets alarm + hardening scheduled for Day 13.

## SOC 2 mapping
- Establishing and recording a known-good baseline → **CC7.1** (detect anomalies /
  changes to the system). You cannot detect drift you never baselined.
