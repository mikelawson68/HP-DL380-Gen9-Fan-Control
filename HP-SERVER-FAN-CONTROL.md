# HP Server Fan Control - Silence of the Fans

## Server Reference

| System | IP | SSH Port | Password | Notes |
|--------|-----|----------|----------|-------|
| System B | 192.168.1.126 | 22 | kaSpik-0kebqo-firpan | HP DL380 Gen9, dual CPU |
| System A | 192.168.1.66 | 22 | hozbax-6zygwe-rAcjem | HAL 9000 banner |
| System C (Cold Storage) | 192.168.1.114 | **10987** | zevpyp-3facce-komryC | 15x 3.5" HDDs |
| System D (Lenovo ST250) | 192.168.1.130 | - | USERID / wubpic-taqkAv-7xasga | XClarity, IPMI disabled - use BIOS |
| Fancontrol VM | 192.168.1.183 | 22 | fan / 073168 | Has scripts (IPMI-based, don't work for Lenovo) |

## SSH Command Template for HP iLO

Requires legacy SSH ciphers:

```bash
sshpass -p 'PASSWORD' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=15 \
  -o KexAlgorithms=+diffie-hellman-group14-sha1 \
  -o HostKeyAlgorithms=+ssh-rsa \
  -o PubkeyAcceptedAlgorithms=+ssh-rsa \
  Administrator@IP 'COMMAND'
```

For .114 (Cold Storage), add `-p 10987` for the non-standard port.

## Silence of the Fans - Full Command Set

**IMPORTANT:** Run commands one at a time with ~3-5 seconds between each command.
`sshpass` intermittently fails auth — retry any "Permission denied" errors.

### Fan Minimums (8% floor)
```
fan p 1 min 8
fan p 2 min 8
fan p 3 min 8
fan p 4 min 8
fan p 5 min 8
fan p 6 min 8
```

### Fan Max Cap (50% ceiling — prevents random 100% spikes)
```
fan p 1 max 50
fan p 2 max 50
fan p 3 max 50
fan p 4 max 50
fan p 5 max 50
fan p 6 max 50
```

### PID Settings
```
fan pid {33,34,35,36,37,38,42,47,52,53,54,55,56,57,58,59,60,61,62,63} lo 2500
fan pid {53,55,57,61,63} hi 2500
```

### OCSD Settings (expanded — all indices)
```
ocsd setts {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45} 2
```

### Disable ALL Temperature Sensors (0-80)
The original 15-sensor list was not enough — unknown sensors outside that range cause fan ramp-up. Disable everything:

```bash
for s in $(seq 0 80); do
  fan t $s off
  # sleep 3-5 seconds between each
done
```

## Lenovo ST250 (System D) Notes

- IPMI over LAN is disabled/locked down by Lenovo
- Fan control must be done through BIOS energy settings
- XClarity web interface at https://192.168.1.130
- **DO NOT hammer SSH - account locks out after failed attempts**
- If locked out, wait for lockout to expire or power cycle

## Status Check Commands

```
fan p              # Show fan percentages (iLO web UI only — doesn't return output over SSH)
fan info           # Show fan info
```

## Notes

- Settings are NOT persistent across iLO/server reboots — re-run script after any reboot
- Safe for low-impact use — hardware thermal shutdown still operates at firmware level regardless of these settings
- iLO may still cause occasional brief fan revs even with all sensors disabled — this is a Gen9 firmware quirk
- The `hp-silence-fans.sh` script has auto-retry (3 attempts) for `sshpass` auth failures

## History

### 2024 Session
- All three HP servers (.126, .66, .114) received the original Silence of the Fans command set (min 12, 15 sensors, PID 3100)
- .126 fans 3 & 4 were running at 23% vs 13-18% on other systems

### Feb 2026 Session
- Upgraded to aggressive defaults: min 8, max 50, PID 2500, all OCSD indices, all sensors 0-80 disabled
- .126 went from 20-26% down to 8-13% after disabling all sensors
- Applied full aggressive treatment to all 3 HP servers
- Updated `hp-silence-fans.sh` to use aggressive settings as default with auto-retry

### Feb 8, 2026 - 3-Day Validation
- **Settings confirmed stable and effective**
- **No thermal issues after 3 days of continuous operation**
- Aggressive settings (min 8%, max 50%, sensors 0-80 disabled) confirmed as optimal balance of noise reduction and thermal safety

**Current Fan Readings (Feb 8, 17:40):**

System A (.66) - HAL 9000: 10%, 18%, 14%, 12%, 14%, 12% (avg 13.3%)
System B (.126): 13%, 15%, 12%, 10%, 14%, 10% (avg 12.3%)
System C (.114) - Cold Storage 15x LFF: 13%, 10%, 7%, 7%, 11%, 7% (avg 9.2%)

**Hardware Optimization:**
- Removed unused/installed video cards from .66 and .126 - significant fan speed reduction
- .114 (cold storage with 15 discs) runs coolest despite disk count, likely due to lower CPU load
