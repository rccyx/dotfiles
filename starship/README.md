# starship Configuration & Themes

A collection of beautiful Starship shell prompt themes with powerline-style bubbles and comprehensive language support.

## Quick Setup

1. **Install Starship** (if not already installed):

   ```bash
   curl -sS https://starship.rs/install.sh | sh
   ```

2. **Copy the themes directory:**

   ```bash
   cp -r starship/ ~/starship/
   ```

3. **Add to your shell config** (`.bashrc`, `.zshrc`, etc.):

   ```bash
   eval "$(starship init bash)"  # or zsh, fish, etc.
   export STARSHIP_CONFIG=~/starship/starship-swirl-rose.toml
   ```

4. **Reload your shell:**
   ```bash
   source ~/.zshrc  # or your whatever shell you use
   ```

## Switching Themes

Change the `STARSHIP_CONFIG` environment variable to point to different theme files:

```bash
# In your shell config (.bashrc, .zshrc, etc.)
export STARSHIP_CONFIG=~/starship/starship-swirl-rose.toml
```

**Available themes:**

- `starship-swirl-rose.toml` - Rose/pink theme (default)
- `starship-catppuccin.toml` - Catppuccin Mocha colors
- `starship-green.toml` - Bright green theme
- `starship-brown.toml` - Brown/earth tones
- `starship-red.toml` - Red accent theme
- `starship-indigo.toml` - Indigo/purple theme
- `starship-black.toml` - Dark theme
- `starship-white.toml` - Light monochrome theme
- `starship-light-purple.toml` - Light purple theme
- `starship-arci.toml` - Arci colorful theme
- `starship-aurora.toml` - Aurora theme

**To switch themes:**

1. Edit your shell config file (`.bashrc`, `.zshrc`, etc.)
2. Change the `STARSHIP_CONFIG` path
3. Reload your shell: `source ~/.bashrc`

## What the Prompt Shows

All themes display the same information in beautiful powerline-style bubbles:

### Left Section (in order):

- **OS Icon** - Shows your operating system (Linux, macOS, etc.)
- **Directory** - Current working directory with smart truncation
  - Icons for special folders (Documents 󰈙, Downloads , Music , Pictures )
  - Truncates long paths with "…/"
- **Git Branch** - Current git branch name
- **Git Status** - Repository status indicators:
  - ✓ Up to date
  - ⇡ Ahead of remote
  - ⇣ Behind remote
  - ↕ Diverged
  - ● Modified files
  - ++ Staged changes
  - ✖ Deleted files
  - ➜ Renamed files
  - ‼ Conflicts
  -  Stashed changes

### Language Section (when applicable):

- **Node.js** () - Version when in a Node.js project
- **Rust** () - Version when in a Rust project
- **Go** () - Version when in a Go project
- **Python** () - Version when in a Python project/environment
- **PHP** () - Version when in a PHP project

### Right Section:

- **Shell** - Current shell (Zsh, VSCode terminal, etc.)
- **Time** - Current time (HH:MM format)

### Bottom:

- **Prompt Character** - ✔ for success, ✖ for error

## Features

- **Smart directory display** - Shows full path until it gets long, then truncates
- **Git integration** - Shows branch and status at a glance
- **Language detection** - Automatically shows relevant runtime versions
- **Cross-platform** - Works on Linux, macOS, Windows (with appropriate shells)
- **Visual feedback** - Color changes and symbols indicate different states
- **Fast** - Minimal performance impact
- **Customizable** - Easy to modify colors and layout
