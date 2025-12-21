#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $EUID -ne 0 ]]; then echo "[ERROR] Run this one as root on the fresh install"; exit 1; fi
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y \
  sudo adduser passwd util-linux coreutils curl wget ca-certificates gnupg \
  locales tzdata \
  network-manager openssh-client \
  rfkill pciutils usbutils lsb-release \
  dbus dbus-user-session \
  man-db less vim nano \
  fontconfig fonts-dejavu fonts-liberation \
  xdg-user-dirs

apt-get install -y firmware-linux firmware-linux-nonfree firmware-misc-nonfree || true

# Initialize XDG user dirs for the chosen user
su - "${main_user:-root}" -c "xdg-user-dirs-update" || true

echo "[OK] Base system is sane. Reboot once if networking was dead. Then log in as your normal user."
