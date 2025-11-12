mkdir -p ~/Pictures/Screenshots

# mac-style capture: save to file, copy to clipboard, then open in swappy
cat > ~/.local/bin/shot-mac <<'EOF'
#!/bin/sh

dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
out="$dir/$(date +'%Y-%m-%d_%H-%M-%S').png"

# find and pause common color filters so they don't tint the capture
pause_filters() {
  # save PIDs if found
  pids=""
  for name in hyprshade gammastep wlsunset redshift; do
    if pgrep -x "$name" >/dev/null 2>&1; then
      pids="$pids $(pgrep -x "$name")"
    fi
  done

  # if Hyprland has a screen shader set, clear it until we finish
  # this silently no-ops if the keyword does not exist on your build
  hyprctl keyword decoration:screen_shader "" >/dev/null 2>&1 || true

  # pause processes so we can resume them exactly as they were
  [ -n "$pids" ] && kill -STOP $pids 2>/dev/null || true

  # tiny settle
  usleep 80000 2>/dev/null || sleep 0.08

  # export list for resume
  export _FILTER_PIDS="${pids# }"
}

resume_filters() {
  [ -n "${_FILTER_PIDS:-}" ] && kill -CONT ${_FILTER_PIDS} 2>/dev/null || true
  # if you normally run hyprshade with a profile, re-enable it here
  # example: hyprshade enable all >/dev/null 2>&1 || true
}

cleanup() {
  resume_filters
}
trap cleanup EXIT

# selection overlay: transparent fill so nothing white or tinted is burned in
geom="$(slurp -b '#00000066' -s '#00ffffff' -c '#ffffffff' -w 2)"

pause_filters

# final settle to ensure overlays are gone
usleep 80000 2>/dev/null || sleep 0.08

# capture, save, and copy in one pass
grim -t png -g "$geom" - \
  | tee "$out" \
  | wl-copy

notify-send "📸 Saved + copied" "$out"

# annotate in swappy, writing back to same file when supported
if swappy --help 2>/dev/null | grep -q -- '-o'; then
  swappy -f "$out" -o "$out" || true
else
  swappy -f "$out" || true
fi
EOF
chmod +x ~/.local/bin/shot-mac

