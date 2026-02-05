# HP DL380 Gen9 Fan Control - "Silence of the Fans"

Automated fan control script for HP ProLiant DL380 Gen9 servers for those who have already sucerssfully installed the mod, but want a way to keep fans quiet if a reboot happens, and it runs every 30 minutes to make sure you're quiet. Reduces fan noise significantly by adjusting iLO fan parameters via SSH. I run this on a VM on a non HP server, and it constantly connecting to all three of my DL380 Gen9 systems, and keeps them between 11-20% fans and low volume. Your mileage may vary. 

## Tested Configuration

- **Server**: HP ProLiant DL380 Gen9
- **iLO Version**: iLO 4 (firmware 2.55+)
- **Mod Version**: The Battle of the Silence of the Fans v1.0 (February 2026)

## The Problem

DL380 Gen9 servers are notoriously loud in home/office environments. The default fan curves are aggressive, often running fans at 30-50% even at idle temperatures. This is fine in a datacenter but unbearable in a home lab.

## The Solution - Install Silence of the Fans. Great, works awesome, but everytime you restart you have to run the iLo commands again in CLI while the fans scream. This is my solution.

This script uses undocumented iLO SSH commands to:

1. **Lower fan minimums** - Set minimum fan speed to 11% (default is much higher)
2. **Adjust PID thresholds** - Raise the temperature threshold before fans spin up
3. **Modify OCSD settings** - Optimize cooling system device behavior
4. **Disable problematic sensors** - Sensors 34 and 35 are the "magic" ones that cause most unnecessary fan ramp-ups

## Requirements

- HP ProLiant DL380 Gen9 (may work on other Gen9 models)
- iLO 4 with SSH enabled
- Successful Mod of Silence of the Fans Work
- `sshpass` utility
- Network access to iLO from the machine running the script

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

## Troubleshooting

### Specific fans still running high

Some fans (often 3 & 4) may run higher than others. Try lowering their minimum further:

```
fan p 3 min 8
fan p 4 min 8
```

Or lower PID thresholds for the magic sensors:

```
fan pid 34 lo 2500
fan pid 35 lo 2500
```

### SSH connection fails

- Verify iLO SSH is enabled (iLO web UI > Administration > Access Settings)
- Check firewall allows port 22 to iLO IP
- Ensure you're using the correct iLO IP (not the server OS IP)

### "Permission denied" errors

- Verify Administrator password is correct
- Check for account lockout (too many failed attempts)
- Try connecting manually first to test credentials

## Safety Notes

- These settings reduce fan speeds significantly - monitor temperatures initially
- The script sets minimums to 12%, which is safe for most environments
- If you notice thermal throttling, increase minimums or remove some sensor disables
- Settings reset on iLO reboot, so you can always recover by restarting iLO

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

- Original "Silence of the Fans" research by the HomeLabbers community
- Script automation by Mike Lawson, 2026

## License

MIT License - Use at your own risk. No warranty expressed or implied.
