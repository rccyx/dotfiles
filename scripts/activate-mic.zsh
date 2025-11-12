#!/usr/bin/env zsh
set -euo pipefail

log()  { print -P "%F{4}[*]%f $*"; }
ok()   { print -P "%F{2}[ok]%f $*"; }
warn() { print -P "%F{3}[warn]%f $*"; }
err()  { print -P "%F{1}[err]%f $*"; }

need_rootless() {
  if [[ ${EUID} -eq 0 ]]; then err "Run as your user, not root"; exit 1; fi
}

has_pkg() { dpkg -s "$1" >/dev/null 2>&1; }

apt_install() {
  local pkgs=()
  for p in "$@"; do has_pkg "$p" || pkgs+=("$p"); done
  if (( ${#pkgs[@]} )); then
    log "Installing: ${pkgs[*]}"
    sudo apt-get update -y
    sudo apt-get install -y "${pkgs[@]}"
  else
    ok "Packages already present"
  fi
}

userctl() { systemctl --user "$@"; }

ensure_user_units_enabled() {
  local u
  for u in "$@"; do
    if ! userctl is-enabled "$u" >/dev/null 2>&1; then
      log "Enabling user unit: $u"; userctl enable --now "$u" || true
    else
      ok "User unit enabled: $u"
      userctl start "$u" || true
    fi
  done
}

disable_legacy_pulse() {
  if userctl is-active pulseaudio.service >/dev/null 2>&1 || userctl is-active pulseaudio.socket >/dev/null 2>&1; then
    log "Disabling legacy PulseAudio user units"
    userctl --now disable pulseaudio.service pulseaudio.socket || true
    userctl mask pulseaudio || true
  else
    ok "Legacy PulseAudio not active"
  fi
}

bring_up_pipewire() {
  log "Installing PipeWire stack"
  apt_install pipewire pipewire-pulse wireplumber alsa-utils alsa-ucm-conf libspa-0.2-bluetooth libspa-0.2-jack

  disable_legacy_pulse
  ensure_user_units_enabled pipewire pipewire-pulse wireplumber

  log "Restarting audio services"
  userctl daemon-reload || true
  userctl restart pipewire || true
  userctl restart pipewire-pulse || true
  userctl restart wireplumber || true
  sleep 1
}

unmute_and_set_default_source() {
  # Unmute all capture controls via ALSA
  if command -v amixer >/dev/null 2>&1; then
    log "Unmuting ALSA capture on all cards"
    for c in $(aplay -l 2>/dev/null | awk '/card/{print $3}' | sort -u); do
      amixer -c "$c" set Capture cap >/dev/null 2>&1 || true
      amixer -c "$c" set Mic cap >/dev/null 2>&1 || true
      amixer -c "$c" set Capture 80% >/dev/null 2>&1 || true
      amixer -c "$c" set Mic 80% >/dev/null 2>&1 || true
    done
  fi

  # Pick a reasonable PipeWire source
  if command -v pactl >/dev/null 2>&1; then
    local src line best=""
    while IFS= read -r line; do
      src="${line%%$'\t'*}"
      # prefer real devices over monitor sources
      if [[ "$src" == *"alsa_input"* || "$src" == *".input"* ]] && [[ "$src" != *"monitor"* ]]; then
        best="$src"
        break
      fi
    done < <(pactl list short sources 2>/dev/null)

    if [[ -n "$best" ]]; then
      log "Setting default mic to: $best"
      pactl set-default-source "$best" || true
      pactl set-source-mute "$best" 0 || true
      pactl set-source-volume "$best" 75% || true
      ok "Mic unmuted and set to $best"
    else
      warn "No suitable capture source found via pactl"
    fi
  else
    err "pactl not found"
  fi
}

fix_chrome_flags() {
  # Not strictly needed for mic, but keep Wayland hints consistent
  mkdir -p "$HOME/.config"
  local f="$HOME/.config/chrome-flags.conf"
  if [[ ! -f "$f" ]] || ! grep -q -- '--ozone-platform=wayland' "$f"; then
    log "Writing Chrome flags"
    cat > "$f" <<EOF
--ozone-platform=wayland
EOF
  else
    ok "Chrome flags already set"
  fi
}

verify_stack() {
  local okc=0
  if pactl info >/dev/null 2>&1 && pactl info | grep -q "PulseAudio (on PipeWire"; then
    ok "PipeWire Pulse shim active"; ((okc++))
  else
    err "PipeWire Pulse shim not active"
  fi

  if pactl list sources short 2>/dev/null | grep -v monitor | grep -q .; then
    ok "At least one capture source detected"; ((okc++))
  else
    warn "No capture sources visible in PipeWire"
  fi

  if arecord -l 2>/dev/null | grep -q "card"; then
    ok "ALSA sees capture hardware"; ((okc++))
  else
    warn "ALSA does not list capture devices"
  fi

  print -P "\n%F{6}Quick mic test%f"
  print -P "Run: %F{4}pw-record -v /tmp/mic.wav%f  then speak, Ctrl+C, and play it with  %F{4}pw-play /tmp/mic.wav%f"
  if (( okc < 2 )); then
    warn "Stack still looks weak. Check logs: journalctl --user -u pipewire -u wireplumber -f"
  fi
}

main() {
  need_rootless
  bring_up_pipewire
  unmute_and_set_default_source
  fix_chrome_flags
  verify_stack
  print -P "\n%F{2}Done.%f Open chrome://settings/content/microphone and pick the default source if Meet still asks."
}

main "$@"

