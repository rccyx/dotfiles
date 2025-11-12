#!/usr/bin/env zsh
# setup-clipvault.zsh  hyprland + wayland. no systemd. idempotent.

emulate -L zsh
setopt err_return no_unset pipefail

: "${BIN_DIR:=$HOME/.local/bin}"
: "${STATE_DIR:=$HOME/.local/state/clipvault-setup}"
: "${CACHE_DIR:=$HOME/.cache/clipvault}"
: "${HYPR_CONF:=$HOME/.config/hypr/hyprland.conf}"

# how many entries to keep hot in the DB (we prune to last N on each store)
: "${CLIP_CAP:=200}"

# periodic full wipe every N days (stores last-wipe timestamp in STATE_DIR)
: "${CLEAR_DAYS:=3}"

# watcher tuning
: "${POLL_MS:=500}"
: "${TIMEOUT_S:=2.0}"

# tool paths we generate
WATCH="$BIN_DIR/clipvault-watchers"
PICK_FZF="$BIN_DIR/clipvault-fzf"
PICK_WOFI="$BIN_DIR/clipvault-wofi"
PRUNE_CAP="$BIN_DIR/clipvault-prune-cap"
PERIODIC_CLEAR_STAMP="$STATE_DIR/last_clear.ts"

blue(){ print -P "%F{4}[*]%f $*"; }
ok(){   print -P "%F{2}[ok]%f $*"; }
warn(){ print -P "%F{3}[warn]%f $*"; }
err(){  print -P "%F{1}[err]%f $*"; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }
need_user(){ [[ $EUID -ne 0 ]] || err "run as your user, not root"; }
mkdirp(){ [[ -d "$1" ]] || mkdir -p "$1"; }
make_exec(){ chmod +x "$1" || err "chmod +x $1 failed"; }

assert_env(){
  [[ -n "$WAYLAND_DISPLAY" && -n "$XDG_RUNTIME_DIR" ]] || warn "not in a wayland session. watchers start on next hyprland login"
  have wl-paste || err "wl-clipboard missing (need wl-paste/wl-copy)"
  have wl-copy  || err "wl-clipboard missing (need wl-paste/wl-copy)"
}

ensure_clipvault(){
  if have clipvault; then
    ok "clipvault present"
    return 0
  fi
  if ! have cargo; then
    err "clipvault missing and cargo not found. install Cargo or provide clipvault in PATH"
  fi
  blue "installing clipvault with cargo"
  cargo install clipvault --locked || err "cargo install clipvault failed"
  ok "clipvault installed"
  # Doc: cargo install path and usage are per README and crates.io. :contentReference[oaicite:1]{index=1}
}

write_prune_cap(){
  mkdirp "$BIN_DIR"
  cat > "$PRUNE_CAP" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
CAP="${CLIP_CAP:-200}"

# keep newest CAP, delete older via relative index
# clipvault list prints newest first with numeric id in column 1 per README.
# We compute how many exceed CAP and delete tail by index from bottom up.
# Ref usage: `clipvault list`, `clipvault delete`, and relative index docs.
# https://github.com/Rolv-Apneseth/clipvault
count="$(clipvault list | wc -l | tr -d ' ')"
if [ "${count:-0}" -le "$CAP" ]; then
  exit 0
fi

# Delete from oldest upward using relative index -1 repeatedly
to_delete=$(( count - CAP ))
i=0
while [ "$i" -lt "$to_delete" ]; do
  clipvault delete --index -1 >/dev/null 2>&1 || true
  i=$(( i + 1 ))
done
SH
  make_exec "$PRUNE_CAP"
  ok "prune-by-cap helper -> $PRUNE_CAP"
}

write_watchers(){
  mkdirp "$BIN_DIR" "$STATE_DIR"
  cat > "$WATCH" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

# One watcher for all types with ignore-pattern for browser meta,
# plus focused watchers for text and image if desired.
# Doc baseline: wl-paste --watch clipvault store. :contentReference[oaicite:2]{index=2}

export TIMEOUT_S="${TIMEOUT_S:-2.0}"
export POLL_MS="${POLL_MS:-500}"
PRUNE_CAP="${PRUNE_CAP:-$HOME/.local/bin/clipvault-prune-cap}"

need(){ command -v "$1" >/dev/null 2>&1 || { echo "$1 missing" >&2; exit 1; }; }
need wl-paste
need clipvault

# Avoid dupes
pgrep -fa 'wl-paste .*clipvault store' >/dev/null && exit 0

# Start main watcher
setsid -f sh -c "wl-paste --watch clipvault store --ignore-pattern '^<meta http-equiv=' >/dev/null 2>&1" >/dev/null 2>&1 || true

# Optional focused watchers for better image fidelity, as per README. :contentReference[oaicite:3]{index=3}
setsid -f sh -c "wl-paste --type image --watch clipvault store >/dev/null 2>&1" >/dev/null 2>&1 || true
setsid -f sh -c "wl-paste --type text  --watch clipvault store >/dev/null 2>&1" >/dev/null 2>&1 || true

# Light polling loop to prune by capacity and keep DB tidy
while :; do
  [ -x "$PRUNE_CAP" ] && "$PRUNE_CAP" || :
  usleep=$(printf %d "${POLL_MS}")000
  perl -e "select(undef,undef,undef,$usleep/1000000)" 2>/dev/null || sleep 0.5
done &
SH
  perl -0777 -pe "s/TIMEOUT_S:-2.0/TIMEOUT_S:-$TIMEOUT_S/g" -i "$WATCH" 2>/dev/null || true
  perl -0777 -pe "s/POLL_MS:-500/POLL_MS:-$POLL_MS/g" -i "$WATCH" 2>/dev/null || true
  make_exec "$WATCH"
  ok "watchers -> $WATCH"
}

write_fzf_picker(){
  have fzf || { warn "fzf not found. skipping fzf picker"; return 0; }
  cat > "$PICK_FZF" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
need(){ command -v "$1" >/dev/null 2>&1 || { echo "$1 missing" >&2; exit 1; }; }
need clipvault; need wl-copy; need fzf

# Clipvault prints numeric key in col1, preview in col2+. We select col2 for display,
# but must pipe the whole line back to clipvault get. :contentReference[oaicite:4]{index=4}
sel="$(clipvault list | fzf --no-sort -d $'\t' --with-nth 2 --prompt='clip> ' || true)"
[ -n "$sel" ] || exit 0
clipvault get <<< "$sel" | wl-copy
SH
  make_exec "$PICK_FZF"
  ok "fzf picker -> $PICK_FZF"
}

write_wofi_picker(){
  have wofi || { warn "wofi not found. skipping wofi picker"; return 0; }
  cat > "$PICK_WOFI" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
need(){ command -v "$1" >/dev/null 2>&1 || { echo "$1 missing" >&2; exit 1; }; }
need clipvault; need wl-copy; need wofi

# Wofi mode from README with -d -k tweak to avoid reordering. :contentReference[oaicite:5]{index=5}
sel="$(clipvault list | wofi -S dmenu --pre-display-cmd "echo '%s' | cut -f 2" -d -k /dev/null || true)"
[ -n "$sel" ] || exit 0
clipvault get <<< "$sel" | wl-copy
SH
  make_exec "$PICK_WOFI"
  ok "wofi picker -> $PICK_WOFI"
}

ensure_hypr_autostart(){
  mkdirp "${HYPR_CONF:h}"
  touch "$HYPR_CONF"
  local line='exec-once = wl-paste --watch clipvault store'
  # Insert once, as documented for Hyprland. :contentReference[oaicite:6]{index=6}
  if ! grep -Fq "$line" "$HYPR_CONF" 2>/dev/null; then
    print -- "$line" >> "$HYPR_CONF"
    ok "injected Hyprland exec-once into $HYPR_CONF"
  else
    ok "Hyprland exec-once already present"
  fi

  # also bind a launcher if wofi exists
  if have wofi; then
    local bind="bind = SUPER, X, exec, $PICK_WOFI"
    if ! grep -Fq "$bind" "$HYPR_CONF" 2>/dev/null; then
      print -- "$bind" >> "$HYPR_CONF"
      ok "injected Super+X wofi picker bind"
    fi
  fi
}

periodic_clear(){
  mkdirp "$STATE_DIR"
  local now ts age
  now="$(date +%s)"
  if [[ -s "$PERIODIC_CLEAR_STAMP" ]]; then
    ts="$(<"$PERIODIC_CLEAR_STAMP")"
  else
    ts=0
  fi
  # seconds in CLEAR_DAYS
  local need=$(( CLEAR_DAYS * 86400 ))
  age=$(( now - ts ))
  if (( age >= need )); then
    blue "periodic clear: wiping clipvault DB (>$CLEAR_DAYS days since last wipe)"
    clipvault clear >/dev/null 2>&1 || true
    print -- "$now" > "$PERIODIC_CLEAR_STAMP"
    ok "cleared clipvault DB"
  else
    ok "periodic clear not due"
  fi
}

start_watchers_now(){
  if pgrep -fa 'wl-paste .*clipvault store' >/dev/null; then
    ok "watchers already running"
    return 0
  fi
  [[ -n "$WAYLAND_DISPLAY" && -n "$XDG_RUNTIME_DIR" ]] || { warn "no wayland env in this shell. auto start on next Hyprland login"; return 0; }
  nohup "$WATCH" >/dev/null 2>&1 &
  ok "watchers started"
}

status(){
  print -P "%F{6}== clipvault sample ==%f"
  clipvault list | head -n 5 2>/dev/null || true
  print -P "%F{6}== processes ==%f"
  pgrep -fa 'wl-paste .*clipvault store' || true
  print -P "%F{6}== pickers ==%f"
  [ -x "$PICK_FZF" ]  && echo "$PICK_FZF"  || true
  [ -x "$PICK_WOFI" ] && echo "$PICK_WOFI" || true
}

setup(){
  need_user
  assert_env
  ensure_clipvault
  mkdirp "$BIN_DIR" "$STATE_DIR" "$CACHE_DIR"
  write_prune_cap
  write_watchers
  write_fzf_picker
  write_wofi_picker
  ensure_hypr_autostart
  periodic_clear
  start_watchers_now
  ok "setup complete"
  ok "use Super+X for wofi picker or run: $PICK_FZF"
}

destroy(){
  need_user
  pkill -f 'wl-paste .*clipvault store' 2>/dev/null || true
  rm -f "$WATCH" "$PICK_FZF" "$PICK_WOFI" "$PRUNE_CAP"
  ok "removed helper binaries from $BIN_DIR"
  ok "leaving your clipvault DB intact. run reset to wipe"
}

reset(){
  need_user
  pkill -f 'wl-paste .*clipvault store' 2>/dev/null || true
  clipvault clear >/dev/null 2>&1 || true
  : > "$PERIODIC_CLEAR_STAMP" 2>/dev/null || true
  ok "wiped clipvault DB"
}

usage(){
  cat <<EOF
usage:
  $0 setup      install helpers, inject Hyprland exec-once, start watchers, prune-to-cap, periodic-clear
  $0 destroy    stop watchers and remove helpers (keeps DB)
  $0 status     show processes and recent entries
  $0 reset      wipe clipvault DB, then you can run setup again
env:
  BIN_DIR=$BIN_DIR
  STATE_DIR=$STATE_DIR
  CACHE_DIR=$CACHE_DIR
  HYPR_CONF=$HYPR_CONF
  CLIP_CAP=$CLIP_CAP
  CLEAR_DAYS=$CLEAR_DAYS
  POLL_MS=$POLL_MS
  TIMEOUT_S=$TIMEOUT_S
EOF
}

case "${1:-}" in
  setup)   setup ;;
  destroy) destroy ;;
  status)  status ;;
  reset)   reset ;;
  *) usage; exit 1 ;;
esac

