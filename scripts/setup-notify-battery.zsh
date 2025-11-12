#!/usr/bin/env zsh
# Debian Trixie + Hyprland + Mako
# Idempotent battery notifications with test sweep

emulate -L zsh
setopt err_return pipefail no_unset

# --- tweakables (env overrides allowed) ---
: "${THRESHOLDS:=50 30 20 10 5}"   # fire when level <= these while discharging
: "${COOLDOWN_MIN:=20}"

# --- paths ---
BIN="$HOME/.local/bin/battery-notify"
STATE_DIR="$HOME/.cache/battery-notify"
UNIT_DIR="$HOME/.config/systemd/user"
SVC="$UNIT_DIR/battery-notify.service"
TMR="$UNIT_DIR/battery-notify.timer"

# --- ui helpers ---
blue(){ print -P "%F{4}[*]%f $*"; }
ok(){   print -P "%F{2}[ok]%f $*"; }
warn(){ print -P "%F{3}[warn]%f $*"; }
err(){  print -P "%F{1}[err]%f $*"; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }

need_user_systemd(){
  systemctl --user show-environment >/dev/null 2>&1 || \
    err "User systemd not active. Log into a systemd user session."
}

write_file(){
  local target="$1" content="$2" dir tmp
  dir="${target:h}"; [[ -n "$dir" ]] && mkdir -p "$dir"
  tmp="$(mktemp)"; print -r -- "$content" > "$tmp"
  if [[ -f "$target" ]] && cmp -s "$tmp" "$target"; then
    rm -f "$tmp"; ok "unchanged: $target"
  else
    mv "$tmp" "$target"; ok "wrote: $target"
  fi
}

make_exec(){ chmod +x "$1"; ok "chmod +x $1"; }

install_deps_hint(){
  have notify-send || warn "notify-send missing. Install: sudo apt update && sudo apt install -y libnotify-bin"
  have upower || warn "upower not found. Install: sudo apt update && sudo apt install -y upower"
}

battery_script(){ cat <<'SH'
#!/usr/bin/env bash
set -euo pipefail

THRESHOLDS=(${THRESHOLDS:-50 30 20 10 5})
COOLDOWN_MIN=${COOLDOWN_MIN:-20}
STATE_DIR="${STATE_DIR:-$HOME/.cache/battery-notify}"

mkdir -p "$STATE_DIR"
log(){ printf "[battery-notify] %s\n" "$*"; }

detect_bat(){
  local bat
  if command -v upower >/dev/null 2>&1; then
    bat=$(upower -e | awk '/battery/{print; exit}')
    [[ -n "$bat" ]] && { echo "$bat"; return 0; }
  fi
  bat=$(ls /sys/class/power_supply 2>/dev/null | grep -E '^BAT' | head -n1 || true)
  [[ -n "$bat" ]] && { echo "/sys/class/power_supply/$bat"; return 0; }
  echo ""; return 1
}

read_level_and_state(){
  local dev="$1" level state info
  if [[ "$dev" =~ ^/sys/class/power_supply ]]; then
    level=$(cat "$dev/capacity")
    state=$(tr '[:upper:]' '[:lower:]' < "$dev/status")
  else
    info="$(upower -i "$dev")"
    level=$(awk -F': *' '/percentage/{gsub("%","",$2); print $2}' <<<"$info")
    state=$(awk -F': *' '/state/{print tolower($2)}' <<<"$info")
  fi
  echo "$level" "$state"
}

bucket_for(){
  local lvl="$1" b="100"
  for t in "${THRESHOLDS[@]}"; do
    if (( lvl <= t )); then b="$t"; fi
  done
  echo "$b"
}

should_notify(){
  # do not record cooldown during forced tests
  if [[ "${BAT_FORCE:-0}" = "1" ]]; then
    return 0
  fi
  local bucket="$1" now last_file="$STATE_DIR/last_$bucket"
  now=$(date +%s)
  if [[ -f "$last_file" ]]; then
    local last tsdiff
    last=$(<"$last_file")
    tsdiff=$(( (now - last)/60 ))
    (( tsdiff < COOLDOWN_MIN )) && return 1
  fi
  echo "$now" > "$last_file"
  return 0
}

urgency_for(){
  local bucket="$1"
  if   (( bucket <= 20 )); then echo critical
  elif (( bucket <= 30 )); then echo normal
  else                        echo low
  fi
}

icon_for(){
  local lvl="$1"
  if   (( lvl <= 5 ));   then echo battery-caution-symbolic
  elif (( lvl <= 10 ));  then echo battery-empty-symbolic
  elif (( lvl <= 20 ));  then echo battery-low-symbolic
  elif (( lvl <= 50 ));  then echo battery-medium-symbolic
  else                       echo battery-good-symbolic
  fi
}

send_note(){
  local urgency="$1" title="$2" body="$3" icon="$4"
  if command -v notify-send >/dev/null 2>&1; then
    if [[ "$urgency" = "critical" ]]; then
      notify-send --app-name="Battery" --urgency="$urgency" --expire-time=0 --icon="$icon" "$title" "$body"
    else
      notify-send --app-name="Battery" --urgency="$urgency" --icon="$icon" "$title" "$body"
    fi
  else
    log "notify-send not found. Skipping notification."
  fi
}

main(){
  local dev level state
  dev=$(detect_bat) || { log "no battery device found"; exit 0; }
  read -r level state < <(read_level_and_state "$dev")

  # testing overrides
  if [[ -n "${BAT_FAKE_LEVEL:-}" ]]; then level="$BAT_FAKE_LEVEL"; fi
  if [[ -n "${BAT_FORCE_STATE:-}" ]]; then state="$BAT_FORCE_STATE"; fi
  if [[ "${BAT_FORCE:-0}" = "1" ]]; then state="discharging"; fi

  case "$state" in
    discharging|unknown) ;;  # proceed
    *) exit 0 ;;             # only notify on discharge
  esac

  local bucket urgency icon
  bucket="$(bucket_for "$level")"
  (( level > ${THRESHOLDS[0]} )) && exit 0

  if should_notify "$bucket"; then
    urgency="$(urgency_for "$bucket")"
    icon="$(icon_for "$level")"
    local title
    if   (( bucket >= 30 )); then title="Battery reminder"
    elif (( bucket <= 5  )); then title="Battery critically low"
    elif (( bucket <= 10 )); then title="Battery very low"
    elif (( bucket <= 20 )); then title="Battery low"
    else                         title="Battery reminder"
    fi
    send_note "$urgency" "$title" "$level% remaining" "$icon"
  fi
}
main "$@"
SH
}

service_unit(){ cat <<EOF
[Unit]
Description=Battery notify check
ConditionPathExistsGlob=%t/wayland-*

[Service]
Type=oneshot
Environment=THRESHOLDS="${THRESHOLDS}"
Environment=COOLDOWN_MIN="${COOLDOWN_MIN}"
Environment=STATE_DIR="${STATE_DIR}"
Environment=XDG_RUNTIME_DIR=%t
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=%t/bus
ExecStart=/usr/bin/env bash -lc '\
  export WAYLAND_DISPLAY="\${WAYLAND_DISPLAY:-\$(basename "\$(ls -1 %t/wayland-* 2>/dev/null | head -n1)")}" ; \
  exec %h/.local/bin/battery-notify \
'
EOF
}

timer_unit(){ cat <<'EOF'
[Unit]
Description=Battery notify periodic timer

[Timer]
OnBootSec=2m
OnUnitActiveSec=1m
AccuracySec=15s
Persistent=true
Unit=battery-notify.service

[Install]
WantedBy=timers.target
EOF
}

setup(){
  install_deps_hint
  need_user_systemd

  write_file "$BIN" "$(battery_script)"
  make_exec "$BIN"

  write_file "$SVC" "$(service_unit)"
  write_file "$TMR" "$(timer_unit)"

  # purge any test cooldown state so prod can speak immediately
  rm -rf "$STATE_DIR"; mkdir -p "$STATE_DIR"

  systemctl --user daemon-reload
  systemctl --user enable --now battery-notify.timer
  ok "enabled timer battery-notify.timer"

  # kick a first real check
  systemctl --user start battery-notify.service
  ok "kicked a first check"

  blue "Test a level:  $0 test 15"
  blue "Sweep 0..100:  $0 test-sweep"
}

destroy(){
  need_user_systemd
  systemctl --user stop battery-notify.timer 2>/dev/null || true
  systemctl --user disable battery-notify.timer 2>/dev/null || true
  systemctl --user daemon-reload || true
  rm -f "$SVC" "$TMR"
  ok "removed units"
  rm -f "$BIN"
  ok "removed $BIN"
  rm -rf "$STATE_DIR"
  ok "cleared state dir"
}

status(){
  need_user_systemd
  systemctl --user status --no-pager battery-notify.timer || true
  systemctl --user status --no-pager battery-notify.service || true
}

test_level(){
  local lvl="${1:-15}"
  THRESHOLDS="$THRESHOLDS" COOLDOWN_MIN=0 STATE_DIR="$STATE_DIR" \
  BAT_FORCE=1 BAT_FORCE_STATE=discharging BAT_FAKE_LEVEL="$lvl" "$BIN"
  ok "simulated level $lvl%"
}

test_sweep(){
  blue "sweeping 0..100 to exercise notifications"
  for lvl in {0..100}; do
    THRESHOLDS="$THRESHOLDS" COOLDOWN_MIN=0 STATE_DIR="$STATE_DIR" \
    BAT_FORCE=1 BAT_FORCE_STATE=discharging BAT_FAKE_LEVEL="$lvl" "$BIN"
    sleep 0.08
  done
  ok "sweep done"
}

usage(){
  cat <<EOF
Usage:
  $0 setup                 install service and timer
  $0 destroy               uninstall everything and clear state
  $0 status                show unit status
  $0 test <level>          simulate one notification at <level>%
  $0 test-sweep            iterate 0..100 for visual verification

Env overrides:
  THRESHOLDS="50 30 20 10 5"
  COOLDOWN_MIN=20
EOF
}

case "${1:-}" in
  setup)       setup ;;
  destroy)     destroy ;;
  status)      status ;;
  test)        shift; test_level "${1:-15}" ;;
  test-sweep)  test_sweep ;;
  *)           usage; exit 1 ;;
esac

