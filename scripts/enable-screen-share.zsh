#!/usr/bin/env zsh
set -euo pipefail

log()  { print -P "%F{4}[*]%f $*"; }
ok()   { print -P "%F{2}[ok]%f $*"; }
warn() { print -P "%F{3}[warn]%f $*"; }
err()  { print -P "%F{1}[err]%f $*"; }

need_rootless() {
  if [[ ${EUID} -eq 0 ]]; then
    err "Run as your user, not root"
    exit 1
  fi
}

has_pkg() {
  dpkg -s "$1" >/dev/null 2>&1
}

apt_install() {
  local pkgs=()
  for p in "$@"; do
    has_pkg "$p" || pkgs+=("$p")
  done
  if (( ${#pkgs[@]} )); then
    log "Installing: ${pkgs[*]}"
    sudo apt-get update -y
    sudo apt-get install -y "${pkgs[@]}"
  else
    ok "Packages already present"
  fi
}

apt_purge_if_present() {
  local rm=()
  for p in "$@"; do
    has_pkg "$p" && rm+=("$p")
  done
  if (( ${#rm[@]} )); then
    log "Removing conflicting: ${rm[*]}"
    sudo apt-get purge -y "${rm[@]}"
  else
    ok "No conflicting portals to remove"
  fi
}

userctl() {
  systemctl --user "$@"
}

ensure_user_units_enabled() {
  local units=("$@")
  for u in "${units[@]}"; do
    if ! userctl is-enabled "$u" >/dev/null 2>&1; then
      log "Enabling user unit: $u"
      userctl enable --now "$u" || true
    else
      ok "User unit enabled: $u"
    fi
  done
}

restart_stack() {
  log "Restarting PipeWire stack and portal"
  userctl daemon-reload || true
  userctl restart pipewire || true
  userctl restart pipewire-pulse || true
  userctl restart wireplumber || true
  # Kill stray portals so they respawn cleanly
  killall -q xdg-desktop-portal xdg-desktop-portal-wlr 2>/dev/null || true
  userctl restart xdg-desktop-portal || true
  sleep 1
}

assert_wayland_hypr() {
  if [[ "${XDG_SESSION_TYPE:-}" != "wayland" ]]; then
    warn "XDG_SESSION_TYPE is not wayland. Full screen share requires Wayland"
  fi
  if [[ "${XDG_CURRENT_DESKTOP:-}" != *Hyprland* ]]; then
    warn "XDG_CURRENT_DESKTOP does not contain Hyprland. Detected: ${XDG_CURRENT_DESKTOP:-unset}"
  fi
}

fix_audio_stack() {
  log "Configuring audio for Chrome via PipeWire Pulse shim"
  apt_install pipewire pipewire-pulse wireplumber libspa-0.2-bluetooth

  # Make sure legacy pulseaudio does not fight the shim
  if userctl is-active pulseaudio.service >/dev/null 2>&1 || userctl is-active pulseaudio.socket >/dev/null 2>&1; then
    log "Disabling legacy PulseAudio user units"
    userctl --now disable pulseaudio.service pulseaudio.socket || true
    userctl mask pulseaudio || true
  fi

  ensure_user_units_enabled pipewire pipewire-pulse wireplumber
}

fix_portal_stack() {
  log "Installing wlroots portal for Hyprland"
  apt_install xdg-desktop-portal xdg-desktop-portal-wlr

  # Remove DE-specific portals that hijack the backend
  apt_purge_if_present xdg-desktop-portal-gnome xdg-desktop-portal-kde

  ensure_user_units_enabled xdg-desktop-portal
}

write_browser_flags() {
  local chrome_flags="$HOME/.config/chrome-flags.conf"
  local chromium_flags="$HOME/.config/chromium-flags.conf"
  mkdir -p "$HOME/.config"

  local flags=(
    --ozone-platform=wayland
    --enable-features=WebRTCPipeWireCapturer
  )

  # Write atomically if content differs
  local tmp="$(mktemp)"
  printf "%s\n" "${flags[@]}" > "$tmp"
  if [[ ! -f "$chrome_flags" ]] || ! cmp -s "$tmp" "$chrome_flags"; then
    log "Writing $chrome_flags"
    mv "$tmp" "$chrome_flags"
  else
    rm -f "$tmp"
    ok "Chrome flags already set"
  fi

  # Mirror for Chromium if present
  if command -v chromium >/dev/null 2>&1; then
    if [[ ! -f "$chromium_flags" ]] || ! cmp -s "$chrome_flags" "$chromium_flags"; then
      log "Writing $chromium_flags"
      cp "$chrome_flags" "$chromium_flags"
    else
      ok "Chromium flags already set"
    fi
  fi
}

verify_everything() {
  local ok_count=0

  # Portal processes
  if pgrep -x xdg-desktop-portal >/dev/null; then
    ok "xdg-desktop-portal is running"
    ((ok_count++))
  else
    err "xdg-desktop-portal is NOT running"
  fi

  if pgrep -x xdg-desktop-portal-wlr >/dev/null; then
    ok "xdg-desktop-portal-wlr is running"
    ((ok_count++))
  else
    err "xdg-desktop-portal-wlr is NOT running"
  fi

  # PipeWire pulse shim
  if pactl info >/dev/null 2>&1; then
    if pactl info | grep -q "Server Name: PulseAudio (on PipeWire"; then
      ok "PulseAudio shim via PipeWire is active"
      ((ok_count++))
    else
      err "pactl reachable but not using PipeWire Pulse shim"
    fi
  else
    err "pactl cannot talk to audio server"
  fi

  # Mic presence
  if pactl list sources short 2>/dev/null | grep -q .; then
    ok "Microphone sources detected"
    ((ok_count++))
  else
    warn "No mic sources listed via pactl"
  fi

  # Wayland session hints
  assert_wayland_hypr

  if (( ok_count < 3 )); then
    warn "Stack not healthy yet. Check: journalctl --user -u xdg-desktop-portal -f"
  fi
}

main() {
  need_rootless
  fix_audio_stack
  fix_portal_stack
  restart_stack
  write_browser_flags
  verify_everything

  print -P "\n%F{6}Launch Chrome with:%f  google-chrome\nOr Chromium with:  chromium"
  print -P "%F{6}In Google Meet:%f Present now → Entire screen should open the portal picker."
}

main "$@"

