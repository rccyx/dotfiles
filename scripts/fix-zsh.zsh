set -e
ZSH_DIR="$HOME/.oh-my-zsh"

if [ -d "$ZSH_DIR/custom" ]; then
  mv "$ZSH_DIR/custom" "$ZSH_DIR.custom.bak"
fi

rm -rf "$ZSH_DIR.tmp"
git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh "$ZSH_DIR.tmp"
rm -rf "$ZSH_DIR.tmp/.git"

if [ -d "$ZSH_DIR.custom.bak" ]; then
  mkdir -p "$ZSH_DIR.tmp/custom"
  cp -a "$ZSH_DIR.custom.bak/." "$ZSH_DIR.tmp/custom/"
  rm -rf "$ZSH_DIR.custom.bak"
fi

rm -rf "$ZSH_DIR"
mv "$ZSH_DIR.tmp" "$ZSH_DIR"

ZSH_CUSTOM="$ZSH_DIR/custom"
mkdir -p "$ZSH_CUSTOM/plugins"

[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] || \
  git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions \
  "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] || \
  git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting \
  "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

[ -d "$ZSH_CUSTOM/plugins/zsh-completions" ] || \
  git clone --depth 1 https://github.com/zsh-users/zsh-completions \
  "$ZSH_CUSTOM/plugins/zsh-completions"

mkdir -p "$HOME/.cache"

exec zsh

