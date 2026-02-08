# HP DL380 Gen8/Gen9 Fan Control - Silence of the Fans Automation

**Automated script for those who have ALREADY successfully installed the Silence of the Fans mod** on their HP ProLiant servers.

This script automates the manual iLO commands so your fans stay quiet after reboots. Runs every 30 minutes via cron to maintain settings. No more manually re-running commands after every server restart.

**Results:** Fans stay between 8-13% (very quiet) instead of the default 30-50% (jet engine). Run from any machine on your network that can reach the iLO interfaces.

## WARNING - READ BEFORE RUNNING

**This script aggressively reduces fan speeds and disables ALL temperature sensors on your server. Before running this you MUST:**

1. **Monitor your server temperatures** — Have iLO web UI open and watch CPU, memory, and ambient temps for at least 24 hours after applying
2. **Know your room/ambient temperature** — This was developed and tested in a climate-controlled room. If your servers are in a hot closet, garage, or anywhere above ~75F/24C ambient, these settings may not be safe
3. **Understand what this does** — It sets fan minimums to 8%, caps max at 50%, lowers PID thresholds, and disables ALL temperature sensors (0-80). Your fans will NOT automatically ramp up in response to heat
4. **Have a recovery plan** — Settings are NOT persistent across iLO/server reboots. If anything goes wrong, restart iLO and fans return to full automatic control. Hardware thermal shutdown still operates at the firmware level as a last resort
5. **Start conservative if unsure** — Try min 12% with only the standard 15 sensors disabled first (see Manual Configuration below), then go more aggressive once you're comfortable

**This is an experiment. You are responsible for monitoring your hardware. Overheating can damage or destroy components. The author is not responsible for any damage caused by using this script.**

## Tested Configuration

- **Servers**: HP ProLiant DL380 Gen8 & Gen9 (should work on other DL-series)
- **iLO Version**: iLO 4 (firmware 2.55+)
- **Prerequisite**: Silence of the Fans mod successfully installed and tested

### Compatibility

**This script should work on:**
- ✅ HP Gen8 servers (DL380, DL360, etc.) **IF** Silence of the Fans works on your model
- ✅ HP Gen9 servers (DL380, DL360, DL180, ML350, etc.) **IF** Silence of the Fans works on your model
- ✅ Any HP server where you've successfully run the manual Silence of the Fans commands

**This script will NOT work on:**
- ❌ Servers where Silence of the Fans mod doesn't work
- ❌ HP Gen10+ (different iLO commands required)
- ❌ Lenovo servers (use IPMI/XClarity)
- ❌ Dell servers (use iDRAC/IPMI)

## The Problem

DL380 Gen9 servers are notoriously loud in home/office environments. The default fan curves are aggressive, often running fans at 30-50% even at idle temperatures. This is fine in a datacenter but unbearable in a home lab.

## IMPORTANT: This is NOT the Silence of the Fans Mod

⚠️ **This script automates an EXISTING Silence of the Fans installation. It does NOT install the mod for you.**

### Prerequisites

**You MUST have ALREADY successfully installed "Silence of the Fans" on your HP server** before using this script.

**What this script does:**
- ✅ Automates the iLO commands from the Silence of the Fans mod
- ✅ Runs every 30 minutes to maintain settings
- ✅ Applies settings on boot so fans quiet down quickly after restarts
- ✅ Eliminates the need to manually re-run commands after every reboot

**What this script does NOT do:**
- ❌ Install the Silence of the Fans mod for the first time
- ❌ Explain how the mod works
- ❌ Provide troubleshooting for the original mod

### Install Silence of the Fans First

**Before using this automation script, follow the original Silence of the Fans guide:**

- **[HP ILO Fan Control by That-Guy-Jack](https://github.com/That-Guy-Jack/HP-ILO-Fan-Control)** - The original Silence of the Fans guide

Once you've successfully run the manual iLO commands from Jack's guide and verified your fans are quiet, THEN use this script to automate it.

## The Solution - Automated Silence

This script uses undocumented iLO SSH commands to:

1. **Lower fan minimums** - Set minimum fan speed to 8% (default is much higher)
2. **Cap fan maximums** - Set maximum fan speed to 50% (prevents random 100% spikes)
3. **Adjust PID thresholds** - Lower the PID thresholds to 2500 to reduce unnecessary spin-up
4. **Modify OCSD settings** - Set all OCSD indices (0-45) to reduce cooling system overreaction
5. **Disable ALL temperature sensors (0-80)** - The standard 15 sensors aren't enough; unknown sensors outside that range still cause fan ramp-up

## Requirements

- HP ProLiant DL380 Gen9 (may work on other Gen9 models)
- iLO 4 with SSH enabled
- Successful Mod of Silence of the Fans Work
- `sshpass` utility
- Network access to iLO from the machine running the script

## Deployment

### Where to Run This Script

**This script can run from ANY machine on your network** that can reach the iLO interfaces:
- ✅ Raspberry Pi (recommended)
- ✅ Mac Mini / NUC
- ✅ Dedicated VM on a non-HP server
- ✅ Docker container
- ✅ Any Linux/Unix system with network access

**The machine running the script does NOT need to be an HP server.** It just needs:
1. Network connectivity to iLO IPs
2. `sshpass` installed
3. Ability to run cron jobs

### Boot Time Considerations

⚠️ **Best practice: Run from a machine that is NOT one of the HP servers you're controlling.**

**Why:**
- If you run this from a VM **on** an HP DL380, the boot sequence is:
  1. Server powers on → **Fans at 100% (jet engine sound)** 🔊
  2. Host OS boots → Still loud
  3. VM starts → Still loud
  4. Script finally runs → Fans quiet down
  5. **Total loud time: 2-5 minutes**

- If you run from an **external machine** (Raspberry Pi, separate server, etc.):
  1. Server powers on → **Fans at 100%** 🔊
  2. iLO becomes available (~30 seconds)
  3. Script connects and runs immediately → **Fans quiet down**
  4. **Total loud time: 30-60 seconds**

**The external machine approach quiets the fans 4-5x faster** because the script can connect as soon as iLO is available, not after the entire host+VM boot sequence.

### CRITICAL: iLO IPs MUST Be Static

⚠️ **The iLO IP addresses in the script MUST be static (DHCP reservations or static assignments).**

**Why:** The script connects to specific IP addresses hardcoded in the configuration. If an iLO IP changes:
- ❌ Script will fail to connect
- ❌ Fans will return to default aggressive curves
- ❌ Servers will get loud again

**How to ensure static IPs:**
1. Set DHCP reservations in your router/DHCP server (recommended)
2. OR assign static IPs directly in iLO network configuration
3. Document the IPs in this README and your network documentation

**Typical deployment:** Run from a small VM or single-board computer (Raspberry Pi, etc.) that stays powered on 24/7. This ensures the script runs every 30 minutes to maintain fan settings even after server reboots.

## Installation

### 1. Install sshpass

```bash
# Debian/Ubuntu
apt install sshpass

# RHEL/CentOS
yum install sshpass

# macOS
brew install hudochenkov/sshpass/sshpass

# Or build from source (if no sudo access)
curl -LO https://sourceforge.net/projects/sshpass/files/sshpass/1.10/sshpass-1.10.tar.gz
tar xzf sshpass-1.10.tar.gz
cd sshpass-1.10
./configure --prefix=$HOME/local
make && make install
# Then set SSHPASS_PATH=$HOME/local/bin/sshpass
```

### 2. Configure the script

Edit `hp-silence-fans.sh` and update the SERVERS array:

```bash
SERVERS=(
  "Server1:192.168.1.100:22:your_ilo_password"
  "Server2:192.168.1.101:22:your_ilo_password"
)
```

Format: `"NAME:ILO_IP:SSH_PORT:ILO_PASSWORD"`

### 3. Make executable and test

```bash
chmod +x hp-silence-fans.sh
./hp-silence-fans.sh
```

## Automation (Recommended)

**Important**: These settings are NOT persistent across iLO or server reboots. Set up cron to reapply automatically.

```bash
# Edit crontab
crontab -e

# Add these lines:
# Run on boot (with 60s delay for network)
@reboot sleep 60 && /path/to/hp-silence-fans.sh

# Run every 30 minutes to catch any resets
*/30 * * * * /path/to/hp-silence-fans.sh
```

## Command Reference

These are the undocumented iLO commands used:

| Command | Description |
|---------|-------------|
| `fan p` | Show current fan percentages |
| `fan p N min X` | Set fan N minimum to X% |
| `fan p N max X` | Set fan N maximum to X% |
| `fan info` | Show fan information |
| `fan t N off` | Disable temperature sensor N |
| `fan t N` | Show sensor N status |
| `fan pid {sensors} lo X` | Set PID low threshold |
| `fan pid {sensors} hi X` | Set PID high threshold |
| `ocsd setts {sensors} X` | Set OCSD parameters |

## Manual SSH Access

To connect to iLO manually (requires legacy cipher support):

```bash
ssh -o KexAlgorithms=+diffie-hellman-group14-sha1 \
    -o HostKeyAlgorithms=+ssh-rsa \
    -o PubkeyAcceptedAlgorithms=+ssh-rsa \
    Administrator@YOUR_ILO_IP
```

---

## Full Manual Configuration Guide

If you want to run commands manually or understand the complete process.

### Pre-Power Up Configuration (Optional)

Check current power settings:
```
show /system1/oemhp_power1
```

Adjust power cap to 950 Watts (if needed):
```
set /system1/oemhp_power1 oemhp_pwrcap=950
```

Set power regulation mode to Dynamic Power Savings:
```
set /system1/oemhp_power1 oemhp_powerreg=dynamic
```

Power on the server:
```
power on
```

### Post-Boot Fan Configuration (Aggressive - Script Default)

**Step 1: Set Fan Minimum Speeds (8% floor)**
```
fan p 1 min 8
fan p 2 min 8
fan p 3 min 8
fan p 4 min 8
fan p 5 min 8
fan p 6 min 8
```

**Step 2: Set Fan Maximum Speeds (50% ceiling)**
```
fan p 1 max 50
fan p 2 max 50
fan p 3 max 50
fan p 4 max 50
fan p 5 max 50
fan p 6 max 50
```

**Step 3: Set PID Thresholds**
```
fan pid {33,34,35,36,37,38,42,47,52,53,54,55,56,57,58,59,60,61,62,63} lo 2500
fan pid {53,55,57,61,63} hi 2500
```

**Step 4: Set OCSD Settings (all indices)**
```
ocsd setts {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45} 2
```

**Step 5: Disable ALL Temperature Sensors (0-80)**
```bash
# Run each with ~3-5 seconds between commands
for s in $(seq 0 80); do
  fan t $s off
done
```

### Post-Boot Fan Configuration (Conservative - Start Here If Unsure)

If you want to start safe and work your way down:

**Step 1: Set Fan Minimum Speeds (12% floor)**
```
fan p 1 min 12
fan p 2 min 12
fan p 3 min 12
fan p 4 min 12
fan p 5 min 12
fan p 6 min 12
```

**Step 2: Set PID Thresholds**
```
fan pid {33,34,35,36,37,38,42,47,52,53,54,55,56,57,58,59,60,61,62,63} lo 3100
fan pid {53,55,57,61,63} hi 3100
```

**Step 3: Set OCSD Settings**
```
ocsd setts {24,26,27,28,29,30,31,32,44} 2
```

**Step 4: Disable the 15 Known Problem Sensors**

Sensors 34 and 35 have the most impact.
```
fan t 32 off
fan t 45 off
fan t 31 off
fan t 41 off
fan t 37 off
fan t 38 off
fan t 29 off
fan t 34 off
fan t 35 off
fan t 30 off
fan t 40 off
fan t 36 off
fan t 28 off
fan t 33 off
fan t 27 off
```

### Verification Commands

Check fan speeds:
```
show /system1/fan*
fan p
```

Check temperature sensors:
```
show /system1/sensor*
```

Check power consumption:
```
show /system1/oemhp_power1
```

### Expected Outcome

**Aggressive (default):** Fans should settle at around **8-13% speed**. Max capped at 50%.

**Conservative:** Fans should settle at around **13-18% speed**.

- System power usage should stay within configured power cap
- No excessive noise or unnecessary cooling
- Monitor temperatures via iLO web UI — sensors are disabled in CLI but iLO web still shows temps

---

## Troubleshooting

### Specific fans still running high

If using conservative settings, upgrade to the aggressive defaults (script default). If already on aggressive and some fans are still high, you may have a hardware issue or high ambient temperature.

### SSH connection fails

- Verify iLO SSH is enabled (iLO web UI > Administration > Access Settings)
- Check firewall allows port 22 to iLO IP
- Ensure you're using the correct iLO IP (not the server OS IP)

### "Permission denied" errors

- Verify Administrator password is correct
- Check for account lockout (too many failed attempts)
- Try connecting manually first to test credentials

### Commands not working / fans not responding

**Important:** You must unplug iLO power for at least 5 minutes to reset its cached memory. This can cause the mod commands to not work properly.

1. Shut down the server gracefully
2. Unplug the power cables (iLO has capacitor backup)
3. Wait at least 5 minutes
4. Reconnect power and boot
5. Reapply the fan commands

## Safety Notes

- **These settings aggressively reduce fan speeds and disable all temperature sensors — monitor your temperatures closely, especially for the first 24-48 hours**
- **Know your ambient/room temperature before running this** — a hot room changes everything
- The script sets minimums to 8% and caps max at 50% by default
- Hardware thermal shutdown still operates at the firmware level regardless of these settings — if temps hit critical, the server shuts down to protect itself
- If you notice thermal throttling or high temps, restart iLO to restore full automatic fan control
- Settings reset on iLO reboot, so you can always recover by restarting iLO
- The script includes auto-retry (3 attempts) for intermittent `sshpass` auth failures

## Compatibility

**Tested on:** HP ProLiant DL380 Gen9 with iLO 4

**May also work on:**
- HP Gen8 servers - If Silence of the Fans mod works on your Gen8, this script should work too (untested, please report back!)
- Other Gen9 models (DL360, DL380, ML350, etc.)

**Will NOT work on:**
- Lenovo servers (use IPMI/XClarity instead)
- Dell servers (use iDRAC/IPMI)
- HP Gen10+ (different iLO commands)

## Credits

- **Original Silence of the Fans mod:** [That-Guy-Jack's HP ILO Fan Control](https://github.com/That-Guy-Jack/HP-ILO-Fan-Control)
- **Script automation:** Mike Lawson, 2026
- **Community contributions:** ServTheHome forums, r/homelab

## License

MIT License - Use at your own risk. No warranty expressed or implied.
