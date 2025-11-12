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

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "Missing $1"; exit 1; }
}

fzf_pick_timezone() {
  local current tz
  current="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
  tz="$(timedatectl list-timezones | fzf --prompt='Timezone> ' --height=70% --reverse --cycle --border --preview-window=hidden --query="${current:-}" )" || true
  echo -n "${tz:-}"
}

derive_region_pool() {
  # From a timezone like Region/City -> region pool like africa.pool.ntp.org
  local tz="$1" region pool
  region="${tz%%/*}"
  region="${region:l}"        # lower
  case "$region" in
    africa|america|antarctica|asia|atlantic|australia|europe|indian|pacific)
      pool="${region}.pool.ntp.org"
      ;;
    *)
      pool="pool.ntp.org"
      ;;
  esac
  echo -n "$pool"
}

fzf_pick_ntp_servers() {
  local tz="$1"
  local region_pool; region_pool="$(derive_region_pool "$tz")"
  local opts
  opts=$(
    cat <<EOF
Use Debian defaults (clear any custom servers)
Global pool (pool.ntp.org)
Regional pool (${region_pool})
Google (time.google.com)
Cloudflare (time.cloudflare.com)
NIST (time.nist.gov)
Custom: time1.example.com
EOF
  )
  print -P "%F{6}Select one or more NTP sources%f. Space to multi-select. Enter to confirm."
  local selection
  selection="$(print -- "$opts" | fzf --multi --prompt='NTP> ' --height=70% --reverse --cycle --border )" || true
  echo -n "${selection:-}"
}

normalize_ntp_selection() {
  # Input is newline separated choice labels, output is space-separated server list or the keyword DEFAULTS
  local input="$1"
  [[ -z "$input" ]] && { echo -n ""; return; }

  # If the user picked defaults together with others, we honor defaults only
  if print -- "$input" | grep -q '^Use Debian defaults'; then
    echo -n "DEFAULTS"
    return
  fi

  local out=()
  local line
  while IFS= read -r line; do
    case "$line" in
      "Global pool (pool.ntp.org)") out+=("pool.ntp.org") ;;
      "Regional pool ("*)           out+=("${line#Regional pool (}"); out[-1]="${out[-1]%)}" ;;
      "Google (time.google.com)")   out+=("time.google.com") ;;
      "Cloudflare (time.cloudflare.com)") out+=("time.cloudflare.com") ;;
      "NIST (time.nist.gov)")       out+=("time.nist.gov") ;;
      "Custom: "*)                  ;; # handled below
      *)
        # Maybe the user pasted a custom hostname row or edited label
        ;;
    esac
  done <<< "$input"

  # If they selected the Custom template, prompt for actual hostnames
  if print -- "$input" | grep -q '^Custom:'; then
    local custom
    print -n "Enter custom NTP hostnames separated by spaces: "
    read -r custom || true
    [[ -n "${custom:-}" ]] && out+=(${=custom})
  fi

  if (( ${#out[@]} )); then
    # Dedup
    local uniq=()
    local seen=()
    for s in "${out[@]}"; do
      [[ -n "${seen[$s]:-}" ]] || { uniq+=("$s"); seen[$s]=1; }
    done
    print -nr -- "${uniq[*]}"
  else
    echo -n ""
  fi
}

write_timesyncd_override() {
  local servers="$1"
  local dir="/etc/systemd/timesyncd.conf.d"
  local file="$dir/10-custom.conf"
  sudo mkdir -p "$dir"

  if [[ "$servers" == "DEFAULTS" || -z "$servers" ]]; then
    if [[ -f "$file" ]]; then
      log "Clearing custom NTP servers, reverting to Debian defaults"
      # Keep the file but comment Servers out to be explicit
      sudo tee "$file" >/dev/null <<EOF
[Time]
# Servers line intentionally cleared to use distribution defaults
#Servers=
EOF
    else
      ok "No custom NTP override present. Using defaults."
    fi
  else
    log "Setting NTP servers: $servers"
    sudo tee "$file" >/dev/null <<EOF
[Time]
Servers=${servers}
EOF
  fi

  sudo systemctl restart systemd-timesyncd
}

set_timezone() {
  local tz="$1"
  if [[ -z "$tz" ]]; then
    warn "No timezone selected. Skipping timezone change."
    return
  fi
  log "Setting timezone to $tz"
  sudo timedatectl set-timezone "$tz"
}

enable_sync() {
  log "Enabling NTP sync via systemd-timesyncd"
  sudo timedatectl set-ntp true || true
  # Ensure RTC uses UTC to avoid dual boot skew
  sudo timedatectl set-local-rtc 0 || true
}

force_resync() {
  log "Forcing a time sync"
  sudo systemctl restart systemd-timesyncd || true
  # Nudge the service to query immediately
  sudo bash -c 'hash timedatectl 2>/dev/null && timedatectl timesync-status >/dev/null 2>&1 || true'
  sleep 2
}

show_status() {
  print -P "\n%F{6}timedatectl status%f"
  timedatectl status || true
  print -P "\n%F{6}Current time%f"
  date -R || true

  # If available, show sync detail
  if timedatectl timesync-status >/dev/null 2>&1; then
    print -P "\n%F{6}timesync-status%f"
    timedatectl timesync-status || true
  fi
}

main() {
  need_rootless

  apt_install fzf tzdata systemd-timesyncd
  require_cmd fzf
  require_cmd timedatectl

  local chosen_tz; chosen_tz="$(fzf_pick_timezone)"
  set_timezone "$chosen_tz"

  local ntp_raw; ntp_raw="$(fzf_pick_ntp_servers "${chosen_tz:-UTC}")"
  local ntp_servers; ntp_servers="$(normalize_ntp_selection "$ntp_raw")"
  write_timesyncd_override "$ntp_servers"

  enable_sync
  force_resync
  ok "Time configuration applied"

  show_status
}

main "$@"

