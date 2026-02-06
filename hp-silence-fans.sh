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
  local retries=3
  for attempt in $(seq 1 $retries); do
    result=$($SSHPASS -p "$pw" ssh $SSH_OPTS -p "$port" Administrator@"$ip" "$cmd" 2>&1)
    if [[ $? -eq 0 ]]; then
      echo "$result"
      return 0
    fi
    if [[ $attempt -lt $retries ]]; then
      log "  Retry $attempt for: $cmd"
      sleep 3
    fi
  done
  log "  FAILED after $retries attempts: $cmd"
  return 1
}

apply_silence() {
  local name=$1 ip=$2 port=$3 pw=$4

  log "=== Applying Silence of the Fans to $name ($ip) ==="

  # Fan minimums — 8% floor
  for i in 1 2 3 4 5 6; do
    run_ilo_cmd "$ip" "$port" "$pw" "fan p $i min 8"
    sleep 5
  done

  # Fan max cap — 50% prevents random 100% spikes
  for i in 1 2 3 4 5 6; do
    run_ilo_cmd "$ip" "$port" "$pw" "fan p $i max 50"
    sleep 5
  done

  # PID settings — low thresholds to prevent unnecessary spin-up
  run_ilo_cmd "$ip" "$port" "$pw" "fan pid {33,34,35,36,37,38,42,47,52,53,54,55,56,57,58,59,60,61,62,63} lo 2500"
  sleep 5
  run_ilo_cmd "$ip" "$port" "$pw" "fan pid {53,55,57,61,63} hi 2500"
  sleep 5

  # OCSD settings — expanded to all indices
  run_ilo_cmd "$ip" "$port" "$pw" "ocsd setts {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45} 2"
  sleep 5

  # Disable ALL temperature sensors 0-80
  # The standard 15 aren't enough — unknown sensors cause ramp-up
  for sensor in $(seq 0 80); do
    run_ilo_cmd "$ip" "$port" "$pw" "fan t $sensor off"
    sleep 3
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
