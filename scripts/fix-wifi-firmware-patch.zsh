#!/usr/bin/zsh
set -Eeuo pipefail

log(){ printf "[wifi-fix] %s\n" "$*"; }
asroot(){ [ "$EUID" -eq 0 ] && "$@" || sudo "$@"; }
need(){ command -v "$1" >/dev/null || { log "installing $1"; asroot apt-get update -y && asroot apt-get install -y "$1"; }; }

trap 'log "failed at line $LINENO: $BASH_COMMAND"' ERR

log "fix duplicate apt entries if present"
# If main sources already carry non-free-firmware, drop our extra file
if grep -qE 'trixie.*non-free-firmware' /etc/apt/sources.list 2>/dev/null && [ -f /etc/apt/sources.list.d/nonfree.list ]; then
  asroot rm -f /etc/apt/sources.list.d/nonfree.list
fi

log "ensure firmware package is present"
asroot apt-get update -y
asroot apt-get install -y firmware-iwlwifi

# Tools for scraping
need curl
need grep
need sed
need coreutils

log "find newest available jf-b0 firmware on kernel.org"
TREE_URL='https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/tree/?h=main'
HTML="$(curl -fsSL "$TREE_URL")"
VERSIONS="$(printf '%s' "$HTML" | grep -o 'iwlwifi-so-a0-jf-b0-[0-9]\+\.ucode' | sed -E 's/.*-([0-9]+)\.ucode/\1/' | sort -n | uniq)"
NEWEST="$(printf '%s\n' "$VERSIONS" | tail -n1)"

if [ -z "${NEWEST:-}" ]; then
  log "could not discover jf-b0 versions on kernel.org"
  exit 2
fi

RAW_URL="https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/iwlwifi-so-a0-jf-b0-${NEWEST}.ucode?h=main"
TMP="/tmp/iwlwifi-so-a0-jf-b0-${NEWEST}.ucode"
DST="/lib/firmware/iwlwifi-so-a0-jf-b0-${NEWEST}.ucode"

log "downloading jf-b0 ucode ${NEWEST}"
curl -fsSL "$RAW_URL" -o "$TMP"

if [ ! -f "$DST" ] || ! cmp -s "$TMP" "$DST"; then
  log "installing ${NEWEST} into /lib/firmware"
  asroot install -m 0644 "$TMP" "$DST"
  asroot update-initramfs -u
else
  log "ucode ${NEWEST} already present and identical"
fi

log "apply safe stability knobs"
asroot tee /etc/modprobe.d/iwlwifi-stability.conf >/dev/null <<'EOF'
options iwlwifi disable_11ax=1 power_save=0 uapsd_disable=1 lar_disable=1
options iwlmvm power_scheme=1
EOF

log "reload wifi stack"
asroot rfkill unblock all || true
asroot systemctl stop NetworkManager || true
asroot modprobe -r iwlmvm iwlwifi mac80211 cfg80211 || true
asroot modprobe cfg80211
asroot modprobe mac80211
asroot modprobe iwlwifi
asroot modprobe iwlmvm
asroot systemctl restart NetworkManager || true

log "present jf-b0 blobs now:"
ls -1 /lib/firmware/iwlwifi-so-a0-jf-b0-*.ucode 2>/dev/null || true

log "kernel log tail:"
asroot journalctl -k -b | grep -Ei 'iwlwifi|iwlmvm|firmware|cfg80211' | tail -n 80 || true

log "nmcli status:"
nmcli dev status || true

log "scan:"
nmcli dev wifi list || true

log "done"

