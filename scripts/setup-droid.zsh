#!/usr/bin/env zsh
# WhatsApp-on-Linux via Waydroid
# Usage: ./myscript.zsh setup | open | status | destroy

set -Eeuo pipefail

log()  { print -P "%F{4}[*]%f $*"; }
ok()   { print -P "%F{2}[ok]%f $*"; }
warn() { print -P "%F{3}[warn]%f $*"; }
err()  { print -P "%F{1}[err]%f $*"; }
have() { command -v "$1" >/dev/null 2>&1; }
asroot(){ [[ $EUID -eq 0 ]] && "$@" || sudo "$@"; }
need_user(){ [[ $EUID -ne 0 ]] || { err "Run as your user, not root"; exit 1; }; }

pm_is_apt(){ command -v apt-get >/dev/null 2>&1; }

# Paths
REPO_FILE="/etc/apt/sources.list.d/waydroid.list"
WD_DATA="/var/lib/waydroid"
USER_DATA="$HOME/.local/share/waydroid"
BIN_DIR="$HOME/.local/bin"
APPS_DIR="$HOME/.local/share/applications"
WH_BIN="$BIN_DIR/wh"
DESKTOP="$APPS_DIR/whatsapp-waydroid.desktop"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/whatsapp"
APK="$CACHE_DIR/WhatsApp.apk"
APK_URL="https://www.whatsapp.com/android/current/WhatsApp.apk"

trap 'err "failed at line $LINENO"' ERR

ensure_waydroid() {
  if have waydroid; then ok "waydroid present"; return 0; fi
  pm_is_apt || { err "Non apt system. Install Waydroid manually, then re run setup."; }
  log "Adding Waydroid APT repo if missing"
  [[ -f "$REPO_FILE" ]] || curl -fsSL https://repo.waydro.id | sudo bash
  log "Installing waydroid and basics"
  asroot apt-get update -y
  asroot apt-get install -y waydroid wget curl ca-certificates desktop-file-utils xdg-utils
  ok "waydroid installed"
}

inited() {
  sudo test -e "$WD_DATA/images/system.img" || sudo test -e "$WD_DATA/system.img"
}

init_wd() {
  if inited; then
    ok "Waydroid already initialized"
  else
    log "Initializing Waydroid base image"
    asroot waydroid init
    ok "init done"
  fi
  log "Enable and start container"
  asroot systemctl enable waydroid-container || true
  asroot systemctl start  waydroid-container || true
}

session_up() {
  waydroid session start >/dev/null 2>&1 || true
}

install_whatsapp() {
  session_up
  if waydroid app list 2>/dev/null | grep -q '^com.whatsapp'; then
    ok "WhatsApp already installed inside Waydroid"
    return 0
  fi
  mkdir -p "$CACHE_DIR"
  log "Downloading WhatsApp APK"
  wget -q --show-progress -O "$APK" "$APK_URL"
  log "Installing APK into Waydroid"
  waydroid app install "$APK"
  ok "WhatsApp installed"
}

install_launcher() {
  mkdir -p "$BIN_DIR" "$APPS_DIR"

  cat >"$WH_BIN" <<"EOF"
#!/usr/bin/env bash
set -euo pipefail
waydroid session start >/dev/null 2>&1 || true
nohup waydroid show-full-ui >/dev/null 2>&1 &
sleep 2
if waydroid app list 2>/dev/null | grep -q '^com.whatsapp'; then
  waydroid app launch com.whatsapp || true
fi
EOF
  chmod +x "$WH_BIN"
  ok "launcher: $WH_BIN"

  cat >"$DESKTOP" <<EOF
[Desktop Entry]
Name=WhatsApp (Waydroid)
Comment=WhatsApp Android via Waydroid
Exec=$WH_BIN
Terminal=false
Type=Application
Categories=Network;Chat;
EOF
  update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
  ok "desktop entry: $DESKTOP"
}

open_now() {
  session_up
  nohup waydroid show-full-ui >/dev/null 2>&1 &
  sleep 1
  waydroid app launch com.whatsapp >/dev/null 2>&1 || true
  ok "opened Waydroid UI"
}

status_now() {
  if have waydroid; then
    waydroid status || true
    echo
    systemctl status --no-pager waydroid-container || true
  else
    warn "waydroid not installed"
  fi
}

destroy_all() {
  log "Stopping Waydroid"
  asroot waydroid session stop >/dev/null 2>&1 || true
  asroot systemctl stop waydroid-container || true
  asroot systemctl disable waydroid-container || true

  log "Removing launcher and desktop entry"
  rm -f "$WH_BIN" "$DESKTOP"

  if pm_is_apt && dpkg -s waydroid >/dev/null 2>&1; then
    log "Purging waydroid"
    asroot apt-get purge -y waydroid || true
    asroot apt-get autoremove -y || true
  else
    warn "waydroid package not found or non apt system"
  fi

  if [[ -f "$REPO_FILE" ]]; then
    log "Removing Waydroid APT repo"
    asroot rm -f "$REPO_FILE"
    asroot apt-get update -y || true
  fi

  log "Unmounting any leftover mounts"
  asroot umount -l "$USER_DATA" 2>/dev/null || true

  log "Deleting Waydroid data and cache"
  asroot rm -rf "$WD_DATA"
  asroot rm -rf "$USER_DATA"
  rm -rf "$CACHE_DIR" || true

  ok "destroy completed"
}

main() {
  need_user
  case "${1:-}" in
    setup)
      ensure_waydroid
      init_wd
      install_whatsapp
      install_launcher
      ok "Done. Use: wh  or  ./myscript.zsh open"
      ;;
    open)     open_now ;;
    status)   status_now ;;
    destroy)  destroy_all ;;
    *)        echo "Usage: ./myscript.zsh setup | open | status | destroy"; exit 2 ;;
  esac
}

main "$@"

