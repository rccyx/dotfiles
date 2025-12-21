#!/usr/bin/env zsh
# setup-notify-heat.zsh v8.1 - stable source + smoothing for Waybar + sustain gate
# actions: setup | destroy | status | test <C> | test-sweep

emulate -L zsh
setopt err_return pipefail nounset

# ---------- defaults ----------
: "${HEAT_THRESHOLDS:=70 80 85}"      # notify at 70, 80, 85
: "${HEAT_COOLDOWN_MIN:=15}"          # minutes between same-bucket pings
: "${HEAT_MAX_DELTA:=2}"              # max °C step per print tick (smoothing)
: "${HEAT_SMOOTH:=1}"                 # 1 = smooth Waybar print, notify uses raw
: "${HEAT_SUSTAIN_SEC:=10}"           # must hold bucket this many seconds before notify

BIN_NOTIFY="$HOME/.local/bin/heat-notify"
BIN_PRINT="$HOME/.local/bin/cpu-temp"
STATE_DIR="$HOME/.cache/heat-notify"
SRC_FILE="$STATE_DIR/source_path"
LAST_FILE="$STATE_DIR/last_value"
UNIT_DIR="$HOME/.config/systemd/user"
SVC="$UNIT_DIR/heat-notify.service"
TMR="$UNIT_DIR/heat-notify.timer"
SELF="${(%):-%N}"

ok()   { print -P "%F{2}[ok]%f $*"; }
warn() { print -P "%F{3}[warn]%f $*"; }
err()  { print -P "%F{1}[err]%f $*"; exit 1; }

need_user_systemd() { systemctl --user show-environment >/dev/null 2>&1 || err "user systemd not active"; }

write_file() {
  local target="$1" content="$2" dir tmp
  dir="${target:h}"; [[ -n "$dir" ]] && mkdir -p "$dir"
  tmp="$(mktemp)" || err "mktemp failed"
  print -r -- "$content" > "$tmp"
  if [[ -f "$target" ]] && cmp -s "$tmp" "$target"; then
    rm -f "$tmp"; ok "unchanged: $target"
  else
    mv "$tmp" "$target" || err "write failed: $target"
    ok "wrote: $target"
  fi
}
make_exec(){ chmod +x "$1" || err "chmod +x $1"; ok "chmod +x $1"; }

# ---------- payload (bash) ----------
# Notes:
# - Caches the chosen temp file in $STATE_DIR/source_path so it does not flip sources
# - Waybar print is smoothed with HEAT_SMOOTH/HEAT_MAX_DELTA, notifier uses raw
# - Sustain gate requires a bucket to hold for HEAT_SUSTAIN_SEC before notifying
heat_notify_payload() { cat <<'BASH'
#!/usr/bin/env bash
set -o pipefail

HEAT_STATE_DIR="${HEAT_STATE_DIR:-$HOME/.cache/heat-notify}"
SRC_FILE="$HEAT_STATE_DIR/source_path"
LAST_FILE="$HEAT_STATE_DIR/last_value"

read_temp_file() {
  local p="$1" v
  [[ -r "$p" ]] || return 1
  v=$(<"$p") || return 1
  [[ -n "$v" ]] || return 1
  if [[ "$v" -gt 200 ]]; then printf "%d" $((v/1000)); else printf "%d" "$v"; fi
}

find_best_source_path() {
  # 0) explicit override
  if [[ -n "${HEAT_CPU_PATH:-}" ]]; then
    [[ -r "$HEAT_CPU_PATH" ]] && { echo "$HEAT_CPU_PATH"; return 0; }
  fi

  shopt -s nullglob

  # 1) thermal zones, strict priority for stability
  for z in /sys/class/thermal/thermal_zone*; do
    [[ -r "$z/type" && -r "$z/temp" ]] || continue
    read -r typ <"$z/type" || true
    case "${typ,,}" in
      x86_pkg_temp) echo "$z/temp"; return 0 ;;
    esac
  done
  for z in /sys/class/thermal/thermal_zone*; do
    [[ -r "$z/type" && -r "$z/temp" ]] || continue
    read -r typ <"$z/type" || true
    case "${typ,,}" in
      cpu_thermal|soc_thermal|*pkg*temp*) echo "$z/temp"; return 0 ;;
    esac
  done

  # 2) hwmon by name and labels
  for h in /sys/class/hwmon/hwmon*; do
    [[ -r "$h/name" ]] || continue
    read -r nm <"$h/name" || true
    case "${nm,,}" in
      coretemp|k10temp|zenpower|acpitz|pch_*)
        for l in "$h"/temp*_label; do
          [[ -r "$l" ]] || continue
          lbl="$(tr '[:upper:]' '[:lower:]' <"$l")"
          case "$lbl" in
            *tctl*|*tdie*|*package*|*cpu*)
              echo "${l/_label/_input}"; return 0
          esac
        done
        for i in "$h"/temp*_input; do
          echo "$i"; return 0
        done
      ;;
    esac
  done

  # 3) lm-sensors only as a last resort for printing, cannot cache a path
  echo ""
  return 1
}

detect_temp_raw() {
  local t path

  # try cached path first
  if [[ -r "$SRC_FILE" ]]; then
    path="$(<"$SRC_FILE")"
    t="$(read_temp_file "$path")" && { echo "$t"; return 0; }
    # cache stale, drop it
    rm -f "$SRC_FILE"
  fi

  # resolve and cache
  path="$(find_best_source_path)"
  if [[ -n "$path" ]]; then
    t="$(read_temp_file "$path")" && {
      mkdir -p "$HEAT_STATE_DIR"
      printf "%s" "$path" > "$SRC_FILE"
      echo "$t"
      return 0
    }
  fi

  # fallback: parse sensors once, uncached
  if command -v sensors >/dev/null 2>&1; then
    t="$(sensors 2>/dev/null | awk '/(Tctl|Tdie|Package id 0)/{match($0,/[0-9]+(\.[0-9])?/,m); if(m[0]!=""){printf "%.0f\n", m[0]; exit}}')" || true
    [[ -n "$t" ]] && { echo "$t"; return 0; }
  fi

  return 1
}

smooth_for_print() {
  local c="$1" last maxd
  [[ "${HEAT_SMOOTH:-0}" = "0" ]] && { echo "$c"; return 0; }
  mkdir -p "$HEAT_STATE_DIR"
  maxd="${HEAT_MAX_DELTA:-3}"
  if [[ -r "$LAST_FILE" ]]; then
    last="$(<"$LAST_FILE")"
    [[ -n "$last" ]] || last="$c"
    local diff=$(( c - last ))
    if   (( diff >  maxd )); then c=$(( last + maxd ))
    elif (( diff < -maxd )); then c=$(( last - maxd ))
    fi
  fi
  printf "%s" "$c" > "$LAST_FILE"
  echo "$c"
}

bucket_for() {
  local c="$1" b=0
  # shellcheck disable=SC2206
  local THS=(${HEAT_THRESHOLDS:-70 80 85})
  for t in "${THS[@]}"; do [[ "$c" -ge "$t" ]] && b="$t"; done
  echo "$b"
}

urgency_for(){ local b="$1"; if   [[ "$b" -ge 80 ]]; then echo critical; elif [[ "$b" -ge 70 ]]; then echo normal; else echo low; fi; }
title_for(){   local b="$1"; if   [[ "$b" -ge 85 ]]; then echo "CPU emergency - cool now"; elif [[ "$b" -ge 80 ]]; then echo "CPU critical - getting too hot"; elif [[ "$b" -ge 70 ]]; then echo "CPU warm - rising"; else echo "CPU ok"; fi; }
icon_for(){    local b="$1"; if   [[ "$b" -ge 70 ]]; then echo dialog-warning; else echo utilities-system-monitor; fi; }

should_notify() {
  [[ "${HEAT_FORCE:-0}" = "1" ]] && return 0
  local bucket="$1" now last_file="${HEAT_STATE_DIR}/last_bucket" cd_file="${HEAT_STATE_DIR}/cooldown_${bucket}"
  now=$(date +%s)
  local last=0; [[ -f "$last_file" ]] && last=$(<"$last_file")
  if [[ "$bucket" -le "$last" ]]; then
    if [[ -f "$cd_file" ]]; then
      local mins=$(( (now-$(<"$cd_file"))/60 ))
      [[ "$mins" -ge "${HEAT_COOLDOWN_MIN:-10}" ]] && return 0 || return 1
    fi
    return 1
  fi
  echo "$bucket" >"$last_file"; echo "$now" >"$cd_file"; return 0
}

# sustain gate: require continuous time-in-bucket before notifying
sustain_ok() {
  local bucket="$1"
  [[ "${HEAT_FORCE:-0}" = "1" ]] && return 0
  local sustain="${HEAT_SUSTAIN_SEC:-0}"
  [[ "$sustain" -le 0 ]] && return 0

  mkdir -p "$HEAT_STATE_DIR"
  local now curr enter_file curr_file="${HEAT_STATE_DIR}/current_bucket"
  enter_file="${HEAT_STATE_DIR}/enter_${bucket}"
  now=$(date +%s)

  if [[ -r "$curr_file" ]]; then curr="$(<"$curr_file")"; else curr=""; fi

  if [[ "$curr" != "$bucket" ]]; then
    printf "%s" "$bucket" > "$curr_file"
    printf "%s" "$now"    > "$enter_file"
    return 1
  fi

  local start=0
  [[ -f "$enter_file" ]] && start="$(<"$enter_file")"
  [[ -n "$start" ]] || start="$now"

  local elapsed=$(( now - start ))
  [[ "$elapsed" -ge "$sustain" ]] && return 0 || return 1
}

main() {
  local print_only=0 debug=0
  for a in "$@"; do [[ "$a" == "--print" ]] && print_only=1; [[ "$a" == "--debug" ]] && debug=1; done

  local c
  if [[ -n "${HEAT_FAKE_C:-}" ]]; then
    c="$HEAT_FAKE_C"
  else
    c="$(detect_temp_raw)" || { [[ "$print_only" -eq 1 ]] && { echo "N/A"; exit 1; }; exit 0; }
  fi

  if (( debug )); then
    if [[ -r "$SRC_FILE" ]]; then echo "SRC=$(<"$SRC_FILE")" >&2; else echo "SRC=sensors_parse" >&2; fi
  fi

  if [[ "$print_only" -eq 1 ]]; then
    mkdir -p "$HEAT_STATE_DIR"
    c="$(smooth_for_print "$c")"
    echo "$c"
    exit 0
  fi

  mkdir -p "$HEAT_STATE_DIR"
  local b; b="$(bucket_for "$c")"

  # reset current-bucket when below all thresholds
  if [[ "$b" -eq 0 ]]; then
    echo "0" > "${HEAT_STATE_DIR}/current_bucket"
    exit 0
  fi

  # sustain gate first
  if ! sustain_ok "$b"; then
    exit 0
  fi

  # then normal notify policy
  if should_notify "$b"; then
    notify-send --urgency="$(urgency_for "$b")" --icon="$(icon_for "$b")" --app-name="CPU Heat" "$(title_for "$b")" "${c}°C (≥${b}°)" || true
  fi
}

case "$(basename "$0")" in
  cpu-temp) main --print ;;
  *)        main "$@" ;;
esac
BASH
}

cpu_print_wrapper() { cat <<'BASH'
#!/usr/bin/env bash
# Waybar wrapper with smoothing
exec env HEAT_SMOOTH=1 HEAT_MAX_DELTA=2 "$HOME/.local/bin/heat-notify" --print
BASH
}

# ---------- systemd units ----------
service_unit(){ cat <<EOF
[Unit]
Description=CPU heat notify check
ConditionPathExistsGlob=%t/wayland-*

[Service]
Type=oneshot
Environment=PATH=%h/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=HEAT_THRESHOLDS="${HEAT_THRESHOLDS}"
Environment=HEAT_COOLDOWN_MIN="${HEAT_COOLDOWN_MIN}"
Environment=HEAT_STATE_DIR="${STATE_DIR}"
Environment=HEAT_MAX_DELTA="${HEAT_MAX_DELTA}"
Environment=HEAT_SMOOTH=0
Environment=HEAT_SUSTAIN_SEC="${HEAT_SUSTAIN_SEC}"
ExecStart=/usr/bin/env bash -lc '%h/.local/bin/heat-notify || :'
EOF
}

timer_unit(){ cat <<'EOF'
[Unit]
Description=CPU heat notify periodic timer

[Timer]
OnBootSec=30s
OnUnitActiveSec=20s
AccuracySec=5s
Persistent=true
Unit=heat-notify.service

[Install]
WantedBy=timers.target
EOF
}

# ---------- commands ----------
setup(){
  need_user_systemd
  mkdir -p "$STATE_DIR"
  write_file "$BIN_NOTIFY" "$(heat_notify_payload)"; make_exec "$BIN_NOTIFY"
  write_file "$BIN_PRINT"  "$(cpu_print_wrapper)";  make_exec "$BIN_PRINT"
  write_file "$SVC" "$(service_unit)"
  write_file "$TMR" "$(timer_unit)"
  : > "$SRC_FILE"   # reset source cache
  : > "$LAST_FILE"  # clear smoothing state
  : > "$STATE_DIR/current_bucket"
  { setopt local_options null_glob; rm -f "$STATE_DIR"/enter_* 2>/dev/null || true; }
  systemctl --user daemon-reload
  systemctl --user enable --now heat-notify.timer
  ok "enabled heat-notify.timer"
  systemctl --user start heat-notify.service || true
  ok "kicked first check"
  print -P "%F{4}Waybar exec:%f  $BIN_PRINT"
  print -P "%F{4}Test:%f       $SELF test 60   |   $SELF test 70"
}

destroy(){
  need_user_systemd
  systemctl --user stop heat-notify.timer 2>/dev/null || true
  systemctl --user disable heat-notify.timer 2>/dev/null || true
  systemctl --user daemon-reload || true
  rm -f "$SVC" "$TMR" "$BIN_NOTIFY" "$BIN_PRINT"
  ok "removed units and binaries"
  rm -rf "$STATE_DIR"
  ok "cleared state"
}

status(){ need_user_systemd; systemctl --user status --no-pager heat-notify.timer || true; systemctl --user status --no-pager heat-notify.service || true; }

test_level(){
  local c="${1:-60}"
  HEAT_THRESHOLDS="$HEAT_THRESHOLDS" HEAT_COOLDOWN_MIN=0 HEAT_STATE_DIR="$STATE_DIR" HEAT_FORCE=1 HEAT_FAKE_C="$c" "$BIN_NOTIFY"
  ok "simulated CPU ${c}°C"
}

test_sweep(){
  for c in $(seq 55 90); do
    HEAT_THRESHOLDS="$HEAT_THRESHOLDS" HEAT_COOLDOWN_MIN=0 HEAT_STATE_DIR="$STATE_DIR" HEAT_FORCE=1 HEAT_FAKE_C="$c" "$BIN_NOTIFY"
    sleep 0.06
  done
  ok "sweep done"
}

usage(){
  cat <<EOF
Usage:
  $SELF setup | destroy | status | test <C> | test-sweep

Waybar:
  "custom/cpu_temp": { "exec": "$BIN_PRINT", "interval": 2, "format": " {}°C" }

Env:
  HEAT_THRESHOLDS="${HEAT_THRESHOLDS}"
  HEAT_COOLDOWN_MIN=${HEAT_COOLDOWN_MIN}
  HEAT_MAX_DELTA=${HEAT_MAX_DELTA}
  HEAT_SUSTAIN_SEC=${HEAT_SUSTAIN_SEC}
  # optional: HEAT_CPU_PATH=/sys/class/hwmon/.../tempX_input (pins a path)
EOF
}

case "${1:-}" in
  setup) setup ;;
  destroy) destroy ;;
  status) status ;;
  test) shift; test_level "${1:-60}" ;;
  test-sweep) test_sweep ;;
  *) usage; exit 1 ;;
esac

