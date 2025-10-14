
#!/usr/bin/env zsh
# setup-cliphist.zsh  hyprland + wayland. no systemd. idempotent.

emulate -L zsh
setopt err_return no_unset pipefail

: "${CLIP_CAP:=20}"
: "${BIN_DIR:=$HOME/.local/bin}"
: "${STATE_DIR:=$HOME/.local/state/cliphist}"
: "${CACHE_DIR:=$HOME/.cache/cliphist}"
: "${HYPR_CONF:=$HOME/.config/hypr/hyprland.conf}"
: "${POLL_MS:=500}"
: "${TIMEOUT_S:=2.0}"        # increased to handle large clips
: "${STALE_SEC:=300}"
: "${MAX_BYTES:=10485760}"   # 10mb safeguard

STORE="$BIN_DIR/cliphist-store-prune"
WATCH="$BIN_DIR/cliphist-watchers"
FZF_MENU="$BIN_DIR/clip-menu"
WOFI_MENU="$BIN_DIR/clip-wofi"
CACHE_TSV="$CACHE_DIR/top.tsv"
WATCH_PIDFILE="$STATE_DIR/watchers.pid"

blue(){ print -P "%F{4}[*]%f $*"; }
ok(){   print -P "%F{2}[ok]%f $*"; }
warn(){ print -P "%F{3}[warn]%f $*"; }
err(){  print -P "%F{1}[err]%f $*"; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }
need_user(){ [[ $EUID -ne 0 ]] || err "run as your user, not root"; }
mkdirp(){ [[ -d "$1" ]] || mkdir -p "$1"; }
make_exec(){ chmod +x "$1" || err "chmod +x $1 failed"; }

assert_env(){
  have cliphist || err "cliphist missing. install: GO111MODULE=on go install github.com/sentriz/cliphist@latest"
  have wl-copy  || err "wl-clipboard missing"
  have wl-paste || err "wl-clipboard missing"
  have file     || err "file(1) missing"
  command -v fzf  >/dev/null || warn "fzf not found. terminal picker will be skipped"
  command -v wofi >/dev/null || warn "wofi not found. gui picker will be skipped"
  [[ -n "$WAYLAND_DISPLAY" && -n "$XDG_RUNTIME_DIR" ]] || warn "not in a wayland session. watchers start on next hyprland login"
}

write_store(){
  mkdirp "$BIN_DIR" "$CACHE_DIR" "$STATE_DIR"
  cat > "$STORE" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/go/bin:$HOME/.local/bin:$PATH"

CAP="${CLIP_CAP:-20}"
case "$CAP" in (*[!0-9]*|'') CAP=20;; esac

STATE_DIR="${STATE_DIR:-$HOME/.local/state/cliphist}"
CACHE_DIR="${CACHE_DIR:-$HOME/.cache/cliphist}"
LOCKFILE="$STATE_DIR/lockfile"
CACHE_TSV="$CACHE_DIR/top.tsv"
TIMEOUT_S="${TIMEOUT_S:-2.0}"
MAX_BYTES="${MAX_BYTES:-10485760}"

has(){ command -v "$1" >/dev/null 2>&1; }

lock_and_run() {
  if has flock; then
    exec 9>"$LOCKFILE"
    flock -n 9 || exit 0
    "$@"
  else
    LOCKDIR="${LOCKFILE}.d"
    if mkdir "$LOCKDIR" 2>/dev/null; then
      trap 'rmdir "$LOCKDIR" 2>/dev/null || true' EXIT
      "$@"
    else
      exit 0
    fi
  fi
}

store_from_stdin() {
  # stdin -> cliphist
  if [ -t 0 ]; then
    return 1
  fi
  head -c "$MAX_BYTES" | cliphist store || true
  return 0
}

store_from_clipboard() {
  if has timeout; then
    { timeout "$TIMEOUT_S" wl-paste --no-newline 2>/dev/null || true; } | head -c "$MAX_BYTES" | cliphist store || true
    { timeout "$TIMEOUT_S" wl-paste --type image 2>/dev/null || true; } | cliphist store || true
  else
    { ( wl-paste --no-newline 2>/dev/null || true ) & pid=$!; sleep "$TIMEOUT_S"; kill -0 "$pid" 2>/dev/null && kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; } | head -c "$MAX_BYTES" | cliphist store || true
    { ( wl-paste --type image 2>/dev/null || true ) & pid=$!; sleep "$TIMEOUT_S"; kill -0 "$pid" 2>/dev/null && kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; } | cliphist store || true
  fi
}

do_store(){
  if ! store_from_stdin; then
    store_from_clipboard
  fi

  mkdir -p "$CACHE_DIR"
  all="$(mktemp -p "$CACHE_DIR" all.XXXXXX.tsv)"
  keep="$(mktemp -p "$CACHE_DIR" keep.XXXXXX.tsv)"
  old_ids="$(mktemp)"

  cliphist list > "$all" || true
  tail -n "$CAP" "$all" > "$keep" || true
  mv -f "$keep" "$CACHE_TSV"

  total="$(wc -l < "$all" | tr -d ' ')"
  if [ "${total:-0}" -gt "$CAP" ]; then
    head -n "$(( total - CAP ))" "$all" | cut -f1 > "$old_ids" || true
    [ -s "$old_ids" ] && xargs -r -n1 cliphist delete < "$old_ids" || true
  fi

  rm -f "$old_ids" "$all"
}

mkdir -p "$STATE_DIR" "$CACHE_DIR"
lock_and_run do_store
SH
  perl -0777 -pe "s|STATE_DIR:-\\$HOME/.local/state/cliphist|STATE_DIR:-$STATE_DIR|g" -i "$STORE" 2>/dev/null || true
  perl -0777 -pe "s|CACHE_DIR:-\\$HOME/.cache/cliphist|CACHE_DIR:-$CACHE_DIR|g" -i "$STORE" 2>/dev/null || true
  perl -0777 -pe "s/CLIP_CAP:-20/CLIP_CAP:-$CLIP_CAP/g" -i "$STORE" 2>/dev/null || true
  perl -0777 -pe "s/TIMEOUT_S:-2.0/TIMEOUT_S:-$TIMEOUT_S/g" -i "$STORE" 2>/dev/null || true
  perl -0777 -pe "s/MAX_BYTES:-10485760/MAX_BYTES:-$MAX_BYTES/g" -i "$STORE" 2>/dev/null || true
  make_exec "$STORE"
  ok "store+prune+cache -> $STORE"
}

write_watchers(){
  mkdirp "$BIN_DIR" "$STATE_DIR"
  cat > "$WATCH" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/go/bin:$HOME/.local/bin:$PATH"

STATE_DIR="${STATE_DIR:-$HOME/.local/state/cliphist}"
STORE="${STORE_PATH:-$HOME/.local/bin/cliphist-store-prune}"
PIDFILE="$STATE_DIR/watchers.pid"
POLL_MS="${POLL_MS:-500}"
TIMEOUT_S="${TIMEOUT_S:-2.0}"
CACHE_TSV="${CACHE_DIR:-$HOME/.cache/cliphist}/top.tsv"
STALE_SEC="${STALE_SEC:-300}"
MAX_BYTES="${MAX_BYTES:-10485760}"

need_env(){ [ -n "${WAYLAND_DISPLAY:-}" ] && [ -n "${XDG_RUNTIME_DIR:-}" ]; }
running(){ pgrep -fa 'wl-paste .* --watch .*cliphist-store-prune' >/dev/null || pgrep -fa 'cliphist-poller' >/dev/null; }

mkdir -p "$STATE_DIR" "${CACHE_TSV%/*}"

exec 9>"${PIDFILE}.lock"
command -v flock >/dev/null 2>&1 && flock -n 9 || :

need_env || exit 0
running && exit 0
rm -f "$PIDFILE"

setsid -f sh -c "wl-paste --type text           --watch '$STORE' >/dev/null 2>&1" & t1=$! || true
setsid -f sh -c "wl-paste --primary --type text --watch '$STORE' >/dev/null 2>&1" & t2=$! || true
setsid -f sh -c "wl-paste --type image          --watch '$STORE' >/dev/null 2>&1" & t3=$! || true

setsid -f bash -c '
  set -euo pipefail
  STORE="${STORE_PATH:-$HOME/.local/bin/cliphist-store-prune}"
  CACHE_TSV="${CACHE_DIR:-$HOME/.cache/cliphist}/top.tsv"
  POLL_MS="${POLL_MS:-500}"
  TIMEOUT_S="${TIMEOUT_S:-2.0}"
  STALE_SEC="${STALE_SEC:-300}"
  MAX_BYTES="${MAX_BYTES:-10485760}"

  force_store(){
    if out="$(timeout "$TIMEOUT_S" wl-paste --no-newline 2>/dev/null || true)"; then
      if [ -n "$out" ]; then
        printf %s "$out" | head -c "$MAX_BYTES" | "$STORE" || true
      fi
    fi
    if timeout "$TIMEOUT_S" wl-paste --type image >/dev/null 2>&1; then
      timeout "$TIMEOUT_S" wl-paste --type image 2>/dev/null | "$STORE" || true
    fi
  }

  last_txt=""; last_img=""
  force_store

  while :; do
    if [ -f "$CACHE_TSV" ]; then
      now=$(date +%s); mtime=$(stat -c %Y "$CACHE_TSV" 2>/dev/null || echo $now)
      age=$(( now - mtime )); [ "$age" -ge "$STALE_SEC" ] && force_store || :
    else
      force_store
    fi

    txt="$(timeout "$TIMEOUT_S" wl-paste --no-newline 2>/dev/null || true)"
    if [ -n "$txt" ]; then
      h="$(printf %s "$txt" | sha1sum | cut -d" " -f1)"
      if [ "$h" != "$last_txt" ]; then
        printf %s "$txt" | head -c "$MAX_BYTES" | "$STORE" || true
        last_txt="$h"
      fi
    fi

    if timeout "$TIMEOUT_S" wl-paste --type image >/dev/null 2>&1; then
      img_h="$(timeout "$TIMEOUT_S" wl-paste --type image 2>/dev/null | sha1sum | cut -d" " -f1 || true)"
      if [ -n "$img_h" ] && [ "$img_h" != "$last_img" ]; then
        timeout "$TIMEOUT_S" wl-paste --type image 2>/dev/null | "$STORE" || true
        last_img="$img_h"
      fi
    fi

    usleep=$(printf %d "${POLL_MS}")000
    perl -e "select(undef,undef,undef,$usleep/1000000)" 2>/dev/null || sleep 0.5
  done
' >/dev/null 2>&1 & t4=$! || true

printf '%s %s %s %s %s\n' "$$" "${t1:-0}" "${t2:-0}" "${t3:-0}" "${t4:-0}" > "$PIDFILE" || true

while sleep 3600; do :; done
SH
  perl -0777 -pe "s|STORE_PATH:-\\$HOME/.local/bin/cliphist-store-prune|STORE_PATH:-$STORE|g" -i "$WATCH" 2>/dev/null || true
  perl -0777 -pe "s|STATE_DIR:-\\$HOME/.local/state/cliphist|STATE_DIR:-$STATE_DIR|g" -i "$WATCH" 2>/dev/null || true
  perl -0777 -pe "s/POLL_MS:-500/POLL_MS:-$POLL_MS/g" -i "$WATCH" 2>/dev/null || true
  perl -0777 -pe "s/TIMEOUT_S:-2.0/TIMEOUT_S:-$TIMEOUT_S/g" -i "$WATCH" 2>/dev/null || true
  perl -0777 -pe "s/STALE_SEC:-300/STALE_SEC:-$STALE_SEC/g" -i "$WATCH" 2>/dev/null || true
  perl -0777 -pe "s/MAX_BYTES:-10485760/MAX_BYTES:-$MAX_BYTES/g" -i "$WATCH" 2>/dev/null || true
  make_exec "$WATCH"
  ok "watchers -> $WATCH"
}

write_fzf_menu(){
  command -v fzf >/dev/null || return 0
  cat > "$FZF_MENU" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/go/bin:$HOME/.local/bin:$PATH"
need(){ command -v "$1" >/dev/null 2>&1 || { echo "$1 missing" >&2; exit 1; }; }
need cliphist; need fzf; need wl-copy; need file
CAP="${CLIP_CAP:-20}"
CACHE_TSV="${CACHE_DIR:-$HOME/.cache/cliphist}/top.tsv"
[ -s "$CACHE_TSV" ] || { echo "cache empty; try again" >&2; exit 0; }
sel="$(
  tac "$CACHE_TSV" | head -n "$CAP" \
  | fzf --ansi --no-sort --cycle \
        --prompt='clip> ' \
        --header='enter copy  ctrl-o open  ctrl-y copy shown text' \
        --delimiter='\t' --with-nth=2.. \
        --bind 'enter:accept' \
        --bind 'ctrl-o:execute-silent(echo {1} | xargs -I{} sh -c "cliphist decode {} > /tmp/clip_$PPID; nohup xdg-open /tmp/clip_$PPID >/dev/null 2>&1 &")' \
        --bind 'ctrl-y:execute-silent(sh -c '\''printf "%s" "{2..}" | sed "s/^\[[^]]*\]\s*//" | wl-copy'\'' )+abort'
) " || exit 0
id="$(printf '%s\n' "$sel" | cut -f1)"; [ -n "$id" ] || exit 0
tmp="$(mktemp -t cliphist_dec_XXXXXX)"
cliphist decode "$id" > "$tmp" || exit 0
mime="$(file -b --mime-type "$tmp")"
if [[ "$mime" == image/* ]]; then
  wl-copy --type image/png < "$tmp"; wl-copy --primary --type image/png < "$tmp"
else
  wl-copy < "$tmp"; wl-copy --primary < "$tmp"
fi
rm -f "$tmp"
SH
  perl -0777 -pe "s/CLIP_CAP:-20/CLIP_CAP:-$CLIP_CAP/g" -i "$FZF_MENU" 2>/dev/null || true
  make_exec "$FZF_MENU"
  ok "tty picker -> $FZF_MENU"
}

write_wofi_menu(){
  command -v wofi >/dev/null || return 0
  cat > "$WOFI_MENU" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/go/bin:$HOME/.local/bin:$PATH"
need(){ command -v "$1" >/dev/null 2>&1 || { echo "$1 missing" >&2; exit 1; }; }
need cliphist; need wofi; need wl-copy; need file
CAP="${CLIP_CAP:-20}"
CACHE_TSV="${CACHE_DIR:-$HOME/.cache/cliphist}/top.tsv"
if [ ! -s "$CACHE_TSV" ]; then
  command -v notify-send >/dev/null 2>&1 && notify-send "cliphist" "cache empty. try again in a second."
  exit 0
fi
sel="$(tac "$CACHE_TSV" | head -n "$CAP" | wofi --dmenu -i -p 'clip>' )" || exit 0
id="$(printf '%s\n' "$sel" | cut -f1)"; [ -n "$id" ] || exit 0
tmp="$(mktemp -t cliphist_dec_XXXXXX)"
cliphist decode "$id" > "$tmp" || exit 0
mime="$(file -b --mime-type "$tmp")"
if [[ "$mime" == image/* ]]; then
  wl-copy --type image/png < "$tmp"; wl-copy --primary --type image/png < "$tmp"
else
  wl-copy < "$tmp"; wl-copy --primary < "$tmp"
fi
rm -f "$tmp"
SH
  perl -0777 -pe "s/CLIP_CAP:-20/CLIP_CAP:-$CLIP_CAP/g" -i "$WOFI_MENU" 2>/dev/null || true
  make_exec "$WOFI_MENU"
  ok "wofi picker -> $WOFI_MENU"
}

stop_dupes(){
  pkill -f 'wl-paste .* --watch .*cliphist-store-prune' 2>/dev/null || true
  pkill -f 'cliphist-poller' 2>/dev/null || true
  pkill -f 'cliphist-watchers' 2>/dev/null || true
  rm -f "$WATCH_PIDFILE"
}

rebuild_cache_fast(){
  mkdirp "$CACHE_DIR"
  local tmp_all="$CACHE_DIR/.all.$$.$RANDOM.tsv"
  local tmp_keep="$CACHE_DIR/.keep.$$.$RANDOM.tsv"
  local tmp_old="$CACHE_DIR/.old.$$.$RANDOM.txt"
  cliphist list > "$tmp_all" 2>/dev/null || :
  tail -n "$CLIP_CAP" "$tmp_all" > "$tmp_keep" 2>/dev/null || :
  mv -f "$tmp_keep" "$CACHE_TSV" 2>/dev/null || :
  local total; total="$(wc -l < "$tmp_all" 2>/dev/null | tr -d ' ' || echo 0)"
  if [ "${total:-0}" -gt "$CLIP_CAP" ]; then
    head -n "$(( total - CLIP_CAP ))" "$tmp_all" | cut -f1 > "$tmp_old" 2>/dev/null || :
    [ -s "$tmp_old" ] && xargs -r -n1 cliphist delete < "$tmp_old" 2>/dev/null || :
  fi
  rm -f "$tmp_all" "$tmp_old"
}

ensure_hypr_bind(){
  mkdirp "${HYPR_CONF:h}"
  touch "$HYPR_CONF"
  local need1='exec-once = $HOME/.local/bin/cliphist-watchers'
  local need2='bind = SUPER, X, exec, $HOME/.local/bin/clip-wofi'
  if ! grep -Fq "$need1" "$HYPR_CONF" 2>/dev/null; then
    print -- "$need1" >> "$HYPR_CONF"
    ok "injected exec-once into $HYPR_CONF"
  fi
  if command -v wofi >/dev/null 2>&1; then
    if ! grep -Fq "$need2" "$HYPR_CONF" 2>/dev/null; then
      print -- "$need2" >> "$HYPR_CONF"
      ok "injected super+x bind into $HYPR_CONF"
    fi
  fi
}

ensure_tmux_integration(){
  if ! command -v tmux >/dev/null 2>&1; then
    warn "tmux not found. skipping tmux clipboard integration"
    return 0
  fi
  local tmux_main="$HOME/.tmux.conf"
  local tmux_snip_dir="$HOME/.config/tmux"
  local tmux_snip="$tmux_snip_dir/cliphist.conf"
  mkdir -p "$tmux_snip_dir"
  cat > "$tmux_snip" <<'TMUX'
# cliphist wayland bridge
set -g set-clipboard on
bind -T copy-mode-vi y send -X copy-pipe-and-cancel "wl-copy --trim-newline"
bind -T copy-mode-vi Enter send -X copy-pipe-and-cancel "wl-copy --trim-newline"
bind -T copy-mode MouseDragEnd1Pane send -X copy-pipe-and-cancel "wl-copy --trim-newline"
bind y capture-pane \; save-buffer - \; delete-buffer \; run-shell "tmux save-buffer - | wl-copy --trim-newline"
TMUX
  if [ -f "$tmux_main" ]; then
    if ! grep -Fq "source-file $tmux_snip" "$tmux_main" 2>/dev/null; then
      printf '\n# cliphist integration\nsource-file %s\n' "$tmux_snip" >> "$tmux_main"
      ok "injected tmux bindings into $tmux_main"
      [ -n "$TMUX" ] && tmux source-file "$tmux_main" 2>/dev/null || true
    fi
  else
    printf 'source-file %s\n' "$tmux_snip" > "$tmux_main"
    ok "created $tmux_main with clipboard bindings"
    [ -n "$TMUX" ] && tmux source-file "$tmux_main" 2>/dev/null || true
  fi
}

start_watchers_now(){
  if pgrep -fa 'wl-paste .* --watch .*cliphist-store-prune' >/dev/null || pgrep -fa 'cliphist-poller' >/dev/null; then
    ok "watchers already running"
  else
    [[ -n "$WAYLAND_DISPLAY" && -n "$XDG_RUNTIME_DIR" ]] || { warn "no wayland env in this shell. auto start next hyprland login"; return 0; }
    nohup "$WATCH" >/dev/null 2>&1 &
    ok "watchers started"
  fi
}

status(){
  print -P "%F{6}== processes ==%f"
  pgrep -fa 'wl-paste .* --watch .*cliphist-store-prune' || true
  pgrep -fa 'cliphist-poller' || true
  print -P "%F{6}== cliphist list tail ==%f"
  cliphist list | tail -n 5 2>/dev/null || true
  print -P "%F{6}== cache tail ==%f"
  tail -n 5 "$CACHE_TSV" 2>/dev/null || true
}

setup(){
  need_user
  assert_env
  mkdirp "$STATE_DIR" "$CACHE_DIR" "$BIN_DIR"
  write_store
  write_watchers
  write_fzf_menu
  write_wofi_menu
  stop_dupes
  rebuild_cache_fast
  ensure_hypr_bind
  ensure_tmux_integration
  start_watchers_now
  ok "setup done. use super+X for picker. watchers persist."
}

destroy(){
  need_user
  stop_dupes
  rm -f "$STORE" "$WATCH" "$FZF_MENU" "$WOFI_MENU"
  ok "removed helpers from $BIN_DIR"
  rm -rf "$STATE_DIR"
  ok "cleared $STATE_DIR"
  : > "$CACHE_TSV" 2>/dev/null || true
  ok "cleared cache listing"
}

reset(){
  need_user
  stop_dupes
  command -v cliphist >/dev/null 2>&1 && cliphist wipe 2>/dev/null || true
  : > "$CACHE_TSV" 2>/dev/null || true
  ok "wiped cliphist db and cache"
}

usage(){
  cat <<EOF
usage:
  $0 setup      install helpers, rebuild cache, ensure hypr binds and tmux, start watchers
  $0 destroy    stop watchers and remove helpers, clear state
  $0 status     show watcher processes and cache sample
  $0 reset      wipe cliphist db and cache, then run setup
env:
  CLIP_CAP=$CLIP_CAP  POLL_MS=$POLL_MS  TIMEOUT_S=$TIMEOUT_S  STALE_SEC=$STALE_SEC  MAX_BYTES=$MAX_BYTES
  BIN_DIR=$BIN_DIR    CACHE_DIR=$CACHE_DIR
  STATE_DIR=$STATE_DIR HYPR_CONF=$HYPR_CONF
EOF
}

case "${1:-}" in
  setup)   setup ;;
  destroy) destroy ;;
  status)  status ;;
  reset)   reset; setup ;;
  *) usage; exit 1 ;;
esac

