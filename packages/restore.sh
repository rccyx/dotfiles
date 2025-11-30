#!/usr/bin/env bash
set -euo pipefail
BASEDIR="$(cd "$(dirname "$0")" && pwd)"
APT_ETC="$BASEDIR/apt-etc"

echo "==> Restoring APT sources and keyrings"
if command -v apt >/dev/null && [[ -d "$APT_ETC" ]]; then
  if [[ -f "$APT_ETC/sources.list" ]]; then
    sudo cp -f "$APT_ETC/sources.list" /etc/apt/sources.list || true
  fi

  if [[ -d "$APT_ETC/sources.list.d" ]]; then
    sudo mkdir -p /etc/apt/sources.list.d
    sudo cp -f "$APT_ETC/sources.list.d"/* /etc/apt/sources.list.d/ 2>/dev/null || true
  fi

  if [[ -d "$APT_ETC/trusted.gpg.d" ]]; then
    sudo mkdir -p /etc/apt/trusted.gpg.d
    sudo cp -f "$APT_ETC/trusted.gpg.d"/* /etc/apt/trusted.gpg.d/ 2>/dev/null || true
  fi

  if [[ -d "$APT_ETC/keyrings" ]]; then
    sudo mkdir -p /etc/apt/keyrings
    sudo cp -f "$APT_ETC/keyrings"/* /etc/apt/keyrings/ 2>/dev/null || true
  fi

  sudo apt update || true
fi

echo "==> Installing APT manual packages"
if command -v apt >/dev/null && [[ -f "$BASEDIR/apt-installed.txt" ]]; then
  sudo apt update || true
  xargs -a "$BASEDIR/apt-installed.txt" -r sudo apt install -y || true
fi

echo "==> Replaying dpkg selections (optional)"
if command -v dpkg >/dev/null && [[ -f "$BASEDIR/dpkg-selections.txt" ]]; then
  sudo dpkg --set-selections < "$BASEDIR/dpkg-selections.txt" || true
  sudo apt-get dselect-upgrade -y || true
fi

echo "==> Restoring Snap"
if command -v snap >/dev/null && [[ -f "$BASEDIR/snap-list.txt" ]]; then
  awk 'NR>1 {print $1}' "$BASEDIR/snap-list.txt" | while read -r s; do
    [[ -n "$s" ]] && sudo snap install "$s" || true
  done
fi

echo "==> Restoring Flatpak"
if command -v flatpak >/dev/null; then
  [[ -f "$BASEDIR/flatpak-remotes-system.txt" ]] && awk 'NR>1{print $1,$2}' "$BASEDIR/flatpak-remotes-system.txt" | while read -r name url; do
    flatpak remote-add --if-not-exists "$name" "$url" --system || true
  done
  [[ -f "$BASEDIR/flatpak-remotes-user.txt" ]] && awk 'NR>1{print $1,$2}' "$BASEDIR/flatpak-remotes-user.txt" | while read -r name url; do
    flatpak remote-add --if-not-exists "$name" "$url" --user || true
  done
  [[ -f "$BASEDIR/flatpak-system.txt" ]] && awk '{print $1}' "$BASEDIR/flatpak-system.txt" | xargs -r -n1 flatpak install -y --system || true
  [[ -f "$BASEDIR/flatpak-user.txt"   ]] && awk '{print $1}' "$BASEDIR/flatpak-user.txt"   | xargs -r -n1 flatpak install -y --user   || true
fi

echo "==> Restoring pip3"
[[ -f "$BASEDIR/pip3-freeze.txt" ]] && command -v pip3 >/dev/null && pip3 install -U -r "$BASEDIR/pip3-freeze.txt" || true

echo "==> Restoring pipx"
if command -v pipx >/dev/null && [[ -f "$BASEDIR/pipx-list.json" ]]; then
python3 - "$BASEDIR/pipx-list.json" <<'PY'
import json, subprocess, sys
j=json.load(open(sys.argv[1]))
for p in j.get("venvs",{}).keys():
    try: subprocess.run(["pipx","install",p],check=False)
    except Exception:
        pass
PY
fi

echo "==> Restoring npm and pnpm globals"
[[ -f "$BASEDIR/npm-global.txt"  ]] && command -v npm  >/dev/null && xargs -a "$BASEDIR/npm-global.txt"  -r npm  i -g || true
[[ -f "$BASEDIR/pnpm-global.txt" ]] && command -v pnpm >/dev/null && xargs -a "$BASEDIR/pnpm-global.txt" -r pnpm add -g || true

echo "==> Restoring Cargo and rustup"
[[ -f "$BASEDIR/cargo-crates.txt"      ]] && command -v cargo  >/dev/null && xargs -a "$BASEDIR/cargo-crates.txt" -r -n1 cargo install || true
[[ -f "$BASEDIR/rustup-toolchains.txt" ]] && command -v rustup >/dev/null && awk '{print $1}' "$BASEDIR/rustup-toolchains.txt" | xargs -r -n1 rustup toolchain install || true

echo "==> Restoring Go tools"
if command -v go >/dev/null && [[ -f "$BASEDIR/go-tools.txt" ]]; then
  awk '!/^($|#)/{print $0}' "$BASEDIR/go-tools.txt" | xargs -r -n1 go install || true
fi

echo "==> GNOME keybindings (optional)"
[[ -f "$BASEDIR/keybindings.dconf" ]] && command -v dconf >/dev/null && dconf load /org/gnome/settings-daemon/plugins/media-keys/ < "$BASEDIR/keybindings.dconf" || true

echo "==> Done"
