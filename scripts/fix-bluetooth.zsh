#!/usr/bin/env zsh
# Debian Trixie Bluetooth fix with Wi-Fi watchdog and verbose logs
set -Eeuo pipefail

now()  { date +"%Y-%m-%d %H:%M:%S"; }
log()  { print -P "%F{4}[$(now)] [bt-fix]%f $*"; }
ok()   { print -P "%F{2}[$(now)] [ok]%f $*"; }
warn() { print -P "%F{3}[$(now)] [warn]%f $*"; }
err()  { print -P "%F{1}[$(now)] [err]%f $*"; }

asroot(){ [[ $EUID -eq 0 ]] && "$@" || sudo "$@"; }

has_pkg() { dpkg -s "$1" >/dev/null 2>&1; }
apt_install() {
  local pkgs=()
  for p in "$@"; do has_pkg "$p" || pkgs+=("$p"); done
  if (( ${#pkgs[@]} )); then
    log "Installing: ${pkgs[*]}"
    asroot apt-get update -y
    asroot apt-get install -y "${pkgs[@]}"
  else
    ok "Packages already present"
  fi
}

userctl() { systemctl --user "$@"; }

trap 'err "failed at line $LINENO"; exit 1' ERR

# ---------- Wi-Fi watchdog ----------
have_nmcli(){ command -v nmcli >/dev/null 2>&1; }
wifi_snapshot(){
  if have_nmcli; then
    nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev status | grep ':wifi:' || true
  else
    echo "nmcli not present"
  fi
}
wifi_restore(){
  have_nmcli || { warn "nmcli missing, skipping Wi-Fi restore"; return 0; }
  local line dev ssid
  line="$(wifi_snapshot || true)"
  if ! echo "$line" | grep -q ':connected:'; then
    dev="$(nmcli -t -f DEVICE,TYPE,STATE dev status | awk -F: '$2=="wifi"{print $1; exit}')"
    ssid="$(nmcli -t -f NAME,TYPE con show --active | awk -F: '$2=="wifi"{print $1; exit}')"
    warn "Wi-Fi not connected, restoring"
    nmcli radio wifi on || true
    nmcli dev wifi rescan || true
    if [[ -n "$ssid" ]]; then
      log "Bringing up active SSID: $ssid"
      nmcli -w 12 con up id "$ssid" || true
    elif [[ -n "$dev" ]]; then
      log "Attempting generic connect on $dev"
      nmcli dev connect "$dev" || true
    else
      err "No Wi-Fi device found by nmcli"
    fi
  else
    ok "Wi-Fi still connected"
  fi
}

# ---------- Packages ----------
print -P "\n%F{6}=== Package prerequisites ===%f"
apt_install bluez bluez-obexd bluez-tools rfkill \
           firmware-misc-nonfree libspa-0.2-bluetooth wireplumber

# optional, only for watchdog if you want it; do not force install
if command -v nmcli >/dev/null 2>&1; then
  ok "nmcli present for Wi-Fi watchdog"
else
  warn "nmcli not found, Wi-Fi watchdog will be limited"
fi

# ---------- Enable and unblock ----------
print -P "\n%F{6}=== Enable and unblock Bluetooth ===%f"
asroot systemctl enable bluetooth.service >/dev/null 2>&1 || true
asroot rfkill unblock bluetooth || true
asroot rfkill unblock all || true
rfkill list || true

# ---------- BlueZ config ----------
print -P "\n%F{6}=== BlueZ configuration ===%f"
asroot install -d -m 0755 /etc/bluetooth
BLUETOOTH_CONF=/etc/bluetooth/main.conf
if [[ -f "$BLUETOOTH_CONF" ]]; then
  log "Editing $BLUETOOTH_CONF"
  asroot sed -i \
    -e 's/^#\?AutoEnable=.*/AutoEnable=true/' \
    -e 's/^#\?Privacy=.*/Privacy=device/' \
    -e 's/^#\?Experimental=.*/Experimental=true/' \
    "$BLUETOOTH_CONF" || true
else
  log "Creating $BLUETOOTH_CONF"
  asroot tee "$BLUETOOTH_CONF" >/dev/null <<'EOF'
[General]
AutoEnable=true
Privacy=device
Experimental=true

[Policy]
AutoEnable=true
EOF
fi
asroot grep -E '^(AutoEnable|Privacy|Experimental)=' "$BLUETOOTH_CONF" || true

# ---------- btusb autosuspend ----------
print -P "\n%F{6}=== Disable btusb autosuspend ===%f"
asroot tee /etc/modprobe.d/btusb.conf >/dev/null <<'EOF'
options btusb enable_autosuspend=N
EOF

# ---------- Snapshot Wi-Fi ----------
print -P "\n%F{6}=== Snapshot Wi-Fi before work ===%f"
before_wifi="$(wifi_snapshot || true)"
log "Wi-Fi before: ${before_wifi:-none}"

# ---------- Restart stack ----------
print -P "\n%F{6}=== Restart Bluetooth stack ===%f"
log "Stopping bluetooth.service"
asroot systemctl stop bluetooth.service || true

log "Reloading btusb kernel modules"
asroot modprobe -r btusb btrtl btintel btbcm || true
asroot modprobe btusb || true

log "Starting bluetooth.service"
asroot systemctl start bluetooth.service

# ---------- PipeWire nudge ----------
print -P "\n%F{6}=== Restart PipeWire user services (if present) ===%f"
if userctl status pipewire.service >/dev/null 2>&1; then
  log "Restart wireplumber"
  userctl restart wireplumber.service || true
  log "Restart pipewire"
  userctl restart pipewire.service || true
  log "Restart pipewire-pulse"
  userctl restart pipewire-pulse.service || true
else
  warn "PipeWire user services not detected, skipping"
fi

# ---------- Prime controller ----------
print -P "\n%F{6}=== Prime controller with bluetoothctl ===%f"
bluetoothctl <<'EOF' >/dev/null 2>&1 || true
power on
agent NoInputNoOutput
default-agent
pairable on
discoverable on
EOF

# ---------- Diagnostics ----------
print -P "\n%F{6}=== Diagnostics ===%f"
log "Kernel messages (tail)"
asroot journalctl -k -b | grep -Ei 'bluetooth|btusb|firmware' | tail -n 120 || true

log "Controller state"
bluetoothctl show || true
bluetoothctl list || true

log "Scan for 10s"
if command -v timeout >/dev/null 2>&1; then
  timeout 10s bluetoothctl scan on || true
else
  # Busybox coreutils-less fallback: start scan, sleep, stop
  bluetoothctl scan on >/dev/null 2>&1 || true
  sleep 10
  bluetoothctl scan off >/dev/null 2>&1 || true
fi
bluetoothctl devices || true

# ---------- Verify and restore Wi-Fi ----------
print -P "\n%F{6}=== Verify Wi-Fi and restore if needed ===%f"
wifi_restore
after_wifi="$(wifi_snapshot || true)"
log "Wi-Fi after: ${after_wifi:-none}"

ok "Done. Pair with: bluetoothctl pair <MAC> then trust <MAC> then connect <MAC>"

