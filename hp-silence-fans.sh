#!/bin/bash
# HP DL380 Gen9 Fan Control - "Silence of the Fans"
# https://github.com/YOUR_REPO_HERE
#
# Auto-runs on boot and periodically to keep fans quiet
# Settings are NOT persistent across iLO/server reboots
#
# Requirements:
#   - sshpass (apt install sshpass or build from source)
#   - SSH access to iLO on each server
#
# Usage:
#   1. Edit the SERVERS section below with your iLO IPs, ports, and passwords
#   2. chmod +x hp-silence-fans.sh
#   3. ./hp-silence-fans.sh
#   4. Set up cron for automatic runs (see README)

LOG="${HP_FAN_LOG:-$HOME/hp-fan-control.log}"
SSHPASS="${SSHPASS_PATH:-sshpass}"

# Legacy SSH options required for iLO
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=15 -o KexAlgorithms=+diffie-hellman-group14-sha1 -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa"

#############################################################################
# CONFIGURE YOUR SERVERS HERE
# Format: "NAME:IP:PORT:PASSWORD"
# Use port 22 unless you've changed iLO SSH port
#############################################################################
SERVERS=(
  "Server1:192.168.1.100:22:your_ilo_password"
  "Server2:192.168.1.101:22:your_ilo_password"
  # Add more servers as needed
)
#############################################################################

log() {
  echo "$(date "+%Y-%m-%d %H:%M:%S") - $1" | tee -a "$LOG"
}

run_ilo_cmd() {
  local ip=$1 port=$2 pw=$3 cmd=$4
  $SSHPASS -p "$pw" ssh $SSH_OPTS -p "$port" Administrator@"$ip" "$cmd" 2>&1
}

apply_silence() {
  local name=$1 ip=$2 port=$3 pw=$4

  log "=== Applying Silence of the Fans to $name ($ip) ==="

  # Fan minimums (12% is quiet but safe, can go as low as 8 if needed)
  for i in 1 2 3 4 5 6; do
    run_ilo_cmd "$ip" "$port" "$pw" "fan p $i min 12"
    sleep 5
  done

  # PID settings - lower thresholds to reduce unnecessary spin-up
  run_ilo_cmd "$ip" "$port" "$pw" "fan pid {33,34,35,36,37,38,42,47,52,53,54,55,56,57,58,59,60,61,62,63} lo 3100"
  sleep 5
  run_ilo_cmd "$ip" "$port" "$pw" "fan pid {53,55,57,61,63} hi 3100"
  sleep 5

  # OCSD settings
  run_ilo_cmd "$ip" "$port" "$pw" "ocsd setts {24,26,27,28,29,30,31,32,44} 2"
  sleep 5

  # Disable temperature sensors that cause unnecessary fan ramp-up
  # Sensors 34 and 35 are the "magic" ones with the most impact
  for sensor in 32 45 31 41 37 38 29 34 35 30 40 36 28 33 27; do
    run_ilo_cmd "$ip" "$port" "$pw" "fan t $sensor off"
    sleep 5
  done

  log "=== Completed $name ==="
}

# Preflight check
if ! command -v $SSHPASS &> /dev/null; then
  echo "ERROR: sshpass not found. Install with: apt install sshpass"
  echo "Or build from source: https://sourceforge.net/projects/sshpass/"
  exit 1
fi

# Main
log "========================================"
log "HP DL380 Gen9 Fan Control Starting"
log "========================================"

for server in "${SERVERS[@]}"; do
  IFS=: read -r name ip port pw <<< "$server"
  apply_silence "$name" "$ip" "$port" "$pw"
done

log "All servers processed"
log "========================================"
