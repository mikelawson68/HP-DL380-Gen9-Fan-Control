#!/bin/bash
# HP DL380 Gen9 Fan Control - "Silence of the Fans"
# UPDATED: Feb 8, 2026 - Aggressive settings (min 8, max 50, PID 2500, sensors 0-80 disabled)
# Auto-runs on boot and periodically to keep fans quiet
# Settings are NOT persistent across iLO/server reboots

LOG="$HOME/hp-fan-control.log"
SSHPASS="$HOME/local/bin/sshpass"

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=15 -o KexAlgorithms=+diffie-hellman-group14-sha1 -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa"

log() {
  echo "$(date "+%Y-%m-%d %H:%M:%S") - $1" | tee -a "$LOG"
}

run_ilo_cmd() {
  local ip=$1 port=$2 pw=$3 cmd=$4
  $SSHPASS -p "$pw" ssh $SSH_OPTS -p "$port" Administrator@"$ip" "$cmd" 2>&1
}

apply_silence() {
  local name=$1 ip=$2 port=$3 pw=$4
  
  log "=== Applying AGGRESSIVE Silence of the Fans to $name ($ip) ==="
  
  # Fan minimums (AGGRESSIVE: 8% instead of old 12%)
  for i in 1 2 3 4 5 6; do
    run_ilo_cmd "$ip" "$port" "$pw" "fan p $i min 8"
    sleep 4
  done
  
  # Fan maximums (NEW: 50% cap to prevent spikes)
  for i in 1 2 3 4 5 6; do
    run_ilo_cmd "$ip" "$port" "$pw" "fan p $i max 50"
    sleep 4
  done
  
  # PID settings (AGGRESSIVE: 2500 instead of old 3100)
  run_ilo_cmd "$ip" "$port" "$pw" "fan pid {33,34,35,36,37,38,42,47,52,53,54,55,56,57,58,59,60,61,62,63} lo 2500"
  sleep 5
  run_ilo_cmd "$ip" "$port" "$pw" "fan pid {53,55,57,61,63} hi 2500"
  sleep 5
  
  # OCSD settings (EXPANDED: all indices instead of old 9)
  run_ilo_cmd "$ip" "$port" "$pw" "ocsd setts {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45} 2"
  sleep 5
  
  # Disable ALL temperature sensors 0-80 (CRITICAL: old version only disabled 15 sensors)
  log "Disabling all sensors 0-80 for $name..."
  for sensor in {0..80}; do
    run_ilo_cmd "$ip" "$port" "$pw" "fan t $sensor off"
    sleep 3
  done
  
  log "=== Completed $name ==="
}

# ==================== OLD SETTINGS (COMMENTED OUT FOR REVERT) ====================
# To revert to old settings, uncomment this function and comment out the one above
#
# apply_silence() {
#   local name=$1 ip=$2 port=$3 pw=$4
#   
#   log "=== Applying OLD Silence of the Fans to $name ($ip) ==="
#   
#   # Fan minimums (OLD: 12%)
#   for i in 1 2 3 4 5 6; do
#     run_ilo_cmd "$ip" "$port" "$pw" "fan p $i min 12"
#     sleep 5
#   done
#   
#   # PID settings (OLD: 3100)
#   run_ilo_cmd "$ip" "$port" "$pw" "fan pid {33,34,35,36,37,38,42,47,52,53,54,55,56,57,58,59,60,61,62,63} lo 3100"
#   sleep 5
#   run_ilo_cmd "$ip" "$port" "$pw" "fan pid {53,55,57,61,63} hi 3100"
#   sleep 5
#   
#   # OCSD settings (OLD: only 9 indices)
#   run_ilo_cmd "$ip" "$port" "$pw" "ocsd setts {24,26,27,28,29,30,31,32,44} 2"
#   sleep 5
#   
#   # Disable temperature sensors (OLD: only 15 sensors)
#   for sensor in 32 45 31 41 37 38 29 34 35 30 40 36 28 33 27; do
#     run_ilo_cmd "$ip" "$port" "$pw" "fan t $sensor off"
#     sleep 5
#   done
#   
#   log "=== Completed $name ==="
# }
# ==================== END OLD SETTINGS ====================

# Main
log "========================================"
log "HP Fan Control Starting (AGGRESSIVE SETTINGS)"
log "========================================"

# System A - HAL 9000
apply_silence "System_A" "192.168.1.66" "22" "hozbax-6zygwe-rAcjem"

# System B
apply_silence "System_B" "192.168.1.126" "22" "kaSpik-0kebqo-firpan"

# System C - Cold Storage (non-standard port)
apply_silence "System_C" "192.168.1.114" "10987" "zevpyp-3facce-komryC"

log "All servers processed"
log "========================================"
