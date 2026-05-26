#!/usr/bin/env bash
set -euo pipefail

# HP iLO 4 quiet fan + temperature watchdog script.
# Target: one HP Gen8/Gen9 server with patched iLO 4 fan commands.
# Tested conceptually for iLO 4 up to 2.77-era patched firmware.
#
# Modes:
#   full      Reapply quiet fan/sensor settings, then run watchdog.
#   watchdog  Read temperatures and raise/restore fan minimums if needed.
#
# Cron idea:
#   */5  * * * * /path/hp-ilo4-quiet-watchdog.sh watchdog
#   */30 * * * * /path/hp-ilo4-quiet-watchdog.sh full
#
# To add more iLO4-family servers, add more records to HP_SERVERS using:
#   "Name|iLO host|SSH port|iLO user|iLO password"

MODE="${1:-full}"
LOG_FILE="${LOG_FILE:-./hp-ilo4-quiet.log}"
REPORT_FILE="${REPORT_FILE:-./hp-ilo4-watchdog-report.json}"
STATE_FILE="${STATE_FILE:-./hp-ilo4-watchdog.state}"
SSHPASS="${SSHPASS:-sshpass}"

HP_SERVERS=(
  "my-hp-server|192.0.2.10|22|Administrator|change-me"
)

NORMAL_FAN_MIN_PERCENT="${NORMAL_FAN_MIN_PERCENT:-8}"
RAISE_FAN_MIN_PERCENT="${RAISE_FAN_MIN_PERCENT:-20}"
EMERGENCY_FAN_MIN_PERCENT="${EMERGENCY_FAN_MIN_PERCENT:-40}"
RAISE_MARGIN_C="${RAISE_MARGIN_C:-5}"
RESTORE_MARGIN_C="${RESTORE_MARGIN_C:-10}"
CRITICAL_MARGIN_C="${CRITICAL_MARGIN_C:-2}"

SSH_OPTS=(
  -o StrictHostKeyChecking=no
  -o ConnectTimeout=15
  -o KexAlgorithms=+diffie-hellman-group14-sha1
  -o HostKeyAlgorithms=+ssh-rsa
  -o PubkeyAcceptedAlgorithms=+ssh-rsa
  -o UserKnownHostsFile=/dev/null
)

log() {
  printf '%s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" | tee -a "$LOG_FILE"
}

field() {
  awk -F'|' -v idx="$2" '{print $idx}' <<<"$1"
}

run_ilo_cmd() {
  local host="$1" port="$2" user="$3" pass="$4" cmd="$5"
  timeout 25 "$SSHPASS" -p "$pass" ssh "${SSH_OPTS[@]}" -p "$port" "$user@$host" "$cmd" 2>&1
}

set_fan_mins() {
  local record="$1" percent="$2" name host port user pass fan
  name="$(field "$record" 1)"
  host="$(field "$record" 2)"
  port="$(field "$record" 3)"
  user="$(field "$record" 4)"
  pass="$(field "$record" 5)"

  log "$name: setting fan minimums to ${percent}%"
  for fan in 1 2 3 4 5 6; do
    run_ilo_cmd "$host" "$port" "$user" "$pass" "fan p $fan min $percent" >>"$LOG_FILE" 2>&1 || true
    sleep 1
  done
}

apply_quiet_settings() {
  local record="$1" name host port user pass fan sensor
  name="$(field "$record" 1)"
  host="$(field "$record" 2)"
  port="$(field "$record" 3)"
  user="$(field "$record" 4)"
  pass="$(field "$record" 5)"

  log "$name: applying iLO4 quiet fan settings"

  for fan in 1 2 3 4 5 6; do
    run_ilo_cmd "$host" "$port" "$user" "$pass" "fan p $fan min $NORMAL_FAN_MIN_PERCENT" >>"$LOG_FILE" 2>&1 || true
    sleep 4
  done

  for fan in 1 2 3 4 5 6; do
    run_ilo_cmd "$host" "$port" "$user" "$pass" "fan p $fan max 50" >>"$LOG_FILE" 2>&1 || true
    sleep 4
  done

  run_ilo_cmd "$host" "$port" "$user" "$pass" "fan pid {33,34,35,36,37,38,42,47,52,53,54,55,56,57,58,59,60,61,62,63} lo 2500" >>"$LOG_FILE" 2>&1 || true
  sleep 5
  run_ilo_cmd "$host" "$port" "$user" "$pass" "fan pid {53,55,57,61,63} hi 2500" >>"$LOG_FILE" 2>&1 || true
  sleep 5
  run_ilo_cmd "$host" "$port" "$user" "$pass" "ocsd setts {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45} 2" >>"$LOG_FILE" 2>&1 || true
  sleep 5

  for sensor in {0..80}; do
    run_ilo_cmd "$host" "$port" "$user" "$pass" "fan t $sensor off" >>"$LOG_FILE" 2>&1 || true
    sleep 3
  done
}

previous_mode_for() {
  [[ -r "$STATE_FILE" ]] || return 0
  awk -F'=' -v name="$1" '$1 == name {print $2; exit}' "$STATE_FILE"
}

watchdog() {
  local report_tmp
  local report_items=()
  local state_lines=()
  report_tmp="$(mktemp)"

  for record in "${HP_SERVERS[@]}"; do
    local name host port user pass json_tmp min_margin critical_margin mode fan_min previous_mode
    name="$(field "$record" 1)"
    host="$(field "$record" 2)"
    port="$(field "$record" 3)"
    user="$(field "$record" 4)"
    pass="$(field "$record" 5)"
    json_tmp="$(mktemp)"

    curl -skS --connect-timeout 5 --max-time 10 -u "$user:$pass" \
      "https://$host/json/health_temperature" -o "$json_tmp"

    min_margin="$(jq -r '[.temperature[] | select(.currentreading != null and .caution != null and .caution > 0) | (.caution - .currentreading)] | if length == 0 then 999 else min end' "$json_tmp")"
    critical_margin="$(jq -r '[.temperature[] | select(.currentreading != null and .critical != null and .critical > 0) | (.critical - .currentreading)] | if length == 0 then 999 else min end' "$json_tmp")"

    mode="normal"
    fan_min="$NORMAL_FAN_MIN_PERCENT"
    if (( critical_margin <= CRITICAL_MARGIN_C )); then
      mode="emergency"
      fan_min="$EMERGENCY_FAN_MIN_PERCENT"
    elif (( min_margin <= RAISE_MARGIN_C )); then
      mode="raised"
      fan_min="$RAISE_FAN_MIN_PERCENT"
    elif (( min_margin < RESTORE_MARGIN_C )); then
      previous_mode="$(previous_mode_for "$name" || true)"
      if [[ "$previous_mode" == "raised" || "$previous_mode" == "emergency" ]]; then
        mode="$previous_mode"
        [[ "$mode" == "emergency" ]] && fan_min="$EMERGENCY_FAN_MIN_PERCENT" || fan_min="$RAISE_FAN_MIN_PERCENT"
      fi
    fi

    previous_mode="$(previous_mode_for "$name" || true)"
    [[ "$mode" == "$previous_mode" ]] || set_fan_mins "$record" "$fan_min"

    log "$name: watchdog mode=$mode nearest-caution-margin=${min_margin}C"
    state_lines+=("$name=$mode")
    report_items+=("$(jq -c --arg name "$name" --arg host "$host" --arg mode "$mode" --argjson fan_min "$fan_min" '
      (.temperature
        | map(select(.currentreading != null))
        | {
            sensor_count: length,
            hottest: (max_by(.currentreading) // {}),
            nearest_caution: (
              map(select(.caution != null and .caution > 0) | . + {margin: (.caution - .currentreading)})
              | min_by(.margin) // {}
            )
          }) + {name: $name, host: $host, mode: $mode, fan_min: $fan_min}
    ' "$json_tmp")")
    rm -f "$json_tmp"
  done

  {
    printf '{\n  "generated_at": "%s",\n  "servers": [\n' "$(date -Is)"
    local first=1 item
    for item in "${report_items[@]}"; do
      [[ "$first" -eq 1 ]] || printf ',\n'
      first=0
      printf '    %s' "$item"
    done
    printf '\n  ]\n}\n'
  } >"$report_tmp"
  install -m 600 "$report_tmp" "$REPORT_FILE"
  rm -f "$report_tmp"

  printf '%s\n' "${state_lines[@]}" >"$STATE_FILE"
  chmod 600 "$STATE_FILE"
}

case "$MODE" in
  full)
    for record in "${HP_SERVERS[@]}"; do
      apply_quiet_settings "$record"
    done
    watchdog
    ;;
  watchdog)
    watchdog
    ;;
  *)
    echo "Usage: $0 [full|watchdog]" >&2
    exit 2
    ;;
esac
