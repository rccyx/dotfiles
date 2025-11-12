  set -euo pipefail
  local theme="${1:-Bibata-Modern-Ice}"
  local size="${2:-24}"
  local sys_dir="/usr/share/icons/${theme}/cursors"
  local user_dir="$HOME/.icons/default/cursors"

  # deps for cursor themes and icon-cache tool
  sudo apt-get update -y
  sudo apt-get install -y bibata-cursor-theme xcursor-themes adwaita-icon-theme libgtk-3-bin

  # base theme selection
  mkdir -p "$HOME/.icons/default" "$user_dir"
  cat > "$HOME/.icons/default/index.theme" <<EOF
[Icon Theme]
Inherits=${theme}
EOF

  # pick a real cursor file to alias to
  local left_ptr="${sys_dir}/left_ptr"
  local pointer="${sys_dir}/pointer"
  local hand1="${sys_dir}/hand1"
  local hand2_sys="${sys_dir}/hand2"

  # ensure left_ptr exists
  if [[ ! -e "$left_ptr" ]]; then
    echo "Could not find ${left_ptr}. Wrong theme name? Using Adwaita."
    sys_dir="/usr/share/icons/Adwaita/cursors"
    left_ptr="${sys_dir}/left_ptr"
  fi

  # create aliases GTK keeps whining about
  ln -sf "$left_ptr"            "$user_dir/arrow"     # arrow -> left_ptr
  ln -sf "$left_ptr"            "$user_dir/left_ptr"  # ensure present

  if   [[ -e "$hand2_sys" ]]; then ln -sf "$hand2_sys" "$user_dir/hand2"
  elif [[ -e "$hand1"    ]]; then ln -sf "$hand1"     "$user_dir/hand2"
  elif [[ -e "$pointer"  ]]; then ln -sf "$pointer"   "$user_dir/hand2"
  else                             ln -sf "$left_ptr"  "$user_dir/hand2"
  fi

  # make sure toolkits can find your overrides
  if ! grep -q "XCURSOR_PATH=" "$HOME/.profile" 2>/dev/null; then
    echo 'export XCURSOR_PATH="$HOME/.icons:/usr/share/icons:/usr/local/share/icons"' >> "$HOME/.profile"
  fi
  export XCURSOR_PATH="$HOME/.icons:/usr/share/icons:/usr/local/share/icons"
  export XCURSOR_THEME="${theme}"
  export XCURSOR_SIZE="${size}"
  export HYPRCURSOR_THEME="${theme}"
  export HYPRCURSOR_SIZE="${size}"

  # optional dconf for apps that read it
  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface cursor-theme "${theme}" || true
    gsettings set org.gnome.desktop.interface cursor-size "${size}" || true
  fi

  # refresh caches and poke apps
  gtk-update-icon-cache -f -t "$HOME/.icons" || true
  gtk-update-icon-cache -f -t /usr/share/icons || true
  pkill -SIGUSR2 waybar 2>/dev/null || true
  pkill wofi 2>/dev/null || true

  echo "Done. If any stubborn app still logs it, restart that app."

