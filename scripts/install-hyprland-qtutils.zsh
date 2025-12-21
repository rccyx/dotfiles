# =====================================================================
# hypr_qtutils - Idempotent builder/installer for hyprland-qtutils
# - Logs everything to ~/.local/share/hypr_qtutils.log
# - Skips rebuild if already installed and up-to-date
# =====================================================================
hypr_qtutils() {
  emulate -L zsh
  setopt err_return no_unset pipe_fail

  local repo="https://github.com/hyprwm/hyprland-qtutils.git"
  local workdir="${XDG_CACHE_HOME:-$HOME/.cache}/hyprland-qtutils"
  local builddir="$workdir/build"
  local logfile="${XDG_DATA_HOME:-$HOME/.local/share}/hypr_qtutils.log"
  local bincheck="/usr/bin/hyprland-dialog"

  mkdir -p "${logfile:h}" "$workdir" "$builddir"

  print -P "%F{4}ℹ️  Logging to $logfile%f"

  {
    echo "===== hypr_qtutils run @ $(date) ====="
    echo "Workdir: $workdir"
    echo "Builddir: $builddir"
  } >>"$logfile"

  # Clone or update repo
  if [[ -d $workdir/.git ]]; then
    git -C "$workdir" fetch origin >>"$logfile" 2>&1
    local behind=$(git -C "$workdir" rev-list HEAD..origin/main --count)
    if (( behind == 0 )) && [[ -x $bincheck ]]; then
      print -P "%F{2}✔ Already installed and up-to-date%f"
      echo "Already up-to-date, skipping build." >>"$logfile"
      return 0
    fi
    git -C "$workdir" reset --hard origin/main >>"$logfile" 2>&1
    print -P "%F{2}✔ Updated repo%f"
  else
    rm -rf "$workdir"
    git clone --depth=1 "$repo" "$workdir" >>"$logfile" 2>&1
    print -P "%F{2}✔ Cloned repo%f"
  fi

  # Clean builddir
  rm -rf "$builddir"/*
  cd "$builddir"

  # Configure
  if ! cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr .. >>"$logfile" 2>&1; then
    print -P "%F{1}✖ CMake configuration failed%f"
    echo "CMake failed." >>"$logfile"
    return 1
  fi

  # Build
  if ! make -j"$(nproc)" >>"$logfile" 2>&1; then
    print -P "%F{1}✖ Build failed%f"
    echo "Build failed." >>"$logfile"
    return 1
  fi

  # Install
  if sudo make install >>"$logfile" 2>&1; then
    print -P "%F{2}✔ Installed hyprland-qtutils successfully%f"
    echo "Install complete." >>"$logfile"
  else
    print -P "%F{1}✖ Install failed%f"
    echo "Install failed." >>"$logfile"
    return 1
  fi

  print -P "%F{4}ℹ️  See detailed log: $logfile%f"
}

