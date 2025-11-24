# tmux Configuration & Themes

A collection of tmux themes and a fully configured tmux setup with vim-friendly keybindings.

## Quick Setup

1. **Copy the main config:**

   ```bash
   cp .tmux.conf ~/.tmux.conf
   ```

2. **Copy the themes directory:**

   ```bash
   cp -r tmux/ ~/tmux/
   ```

3. **Start tmux:**
   ```bash
   tmux
   ```

That's it! The config will auto-install TPM (tmux plugin manager) and plugins on first run.

## Switching Themes

The main config sources a theme file at the bottom. To switch themes, edit `~/.tmux.conf` and change the last line:

```bash
# Current theme (line 109 in .tmux.conf)
source-file ~/tmux/swirl-rose.conf
```

**Available themes:**

- `swirl-rose.conf` - Rose/pink theme (default)
- `catppuccin-mocha.conf` - Catppuccin Mocha colors
- `green.conf` - Bright green theme
- `brown.conf` - Brown/earth tones
- `red.conf` - Red accent theme
- `indigo.conf` - Indigo/purple theme
- `white-band.conf` - Monochrome white theme

**To apply a new theme:**

1. Edit `~/.tmux.conf` and change the `source-file` line
2. Reload config: `Ctrl-a r` (or restart tmux)

## Keybindings & Operations

### Prefix Key

- **Prefix:** `Ctrl-a` (instead of default `Ctrl-b`)
- **Send prefix:** `Ctrl-a Ctrl-a` (to send Ctrl-a to the terminal)

### Window Management

- `Ctrl-a n` - Create new window (in current directory)
- `Ctrl-a h` - Previous window
- `Ctrl-a l` - Next window
- `Ctrl-a |` - Split window vertically (horizontal split)
- `Ctrl-a -` - Split window horizontally (vertical split, 20% top)
- `Ctrl-a c` - Split and open git commit

### Pane Management

- `Ctrl-a b` - Break pane into new window
- `Ctrl-a j` - Join pane from another window (prompts for source)
- `Ctrl-a Ctrl-h/j/k/l` - Navigate panes (vim-style, works in vim too!)
- `Alt-h/j/k/l` - Resize panes (Alt + direction)

### Copy Mode (Vi-style)

- `Ctrl-a [` - Enter copy mode
- `v` - Start visual selection
- `y` - Copy selection to clipboard
- `Enter` - Copy selection to clipboard
- `Space` - Jump to next search result
- `0` - Jump to beginning of line (non-whitespace)
- `Ctrl-a y` - Copy entire buffer to clipboard
- `Ctrl-a Ctrl-y` - Copy entire buffer to clipboard

### Other Operations

- `Ctrl-a r` - Reload tmux config
- Mouse support is enabled (click to select panes, scroll, resize)

## Status Bar Features

The status bar shows:

- **Left:** Current session name
- **Right:**
  - PREFIX indicator (when prefix is active)
  - Git branch (from current pane directory)
  - Hostname
  - Date and time

## Tips

- Windows and panes start numbering at 1 (not 0)
- Windows auto-renumber when closed
- All new windows/panes open in the current directory
- Vim navigation (`Ctrl-h/j/k/l`) works seamlessly - if you're in vim, it sends keys to vim; otherwise it navigates panes
- Copy mode uses vi keybindings - navigate with `h/j/k/l`, search with `/`, etc.

## Plugins

The config includes:

- **tmux-sensible** - Sensible defaults
- **tmux-resurrect** - Save/restore sessions
- **tmux-continuum** - Auto-save sessions every 15 minutes

**Resurrect commands:**

- `Ctrl-a Ctrl-s` - Save session
- `Ctrl-a Ctrl-r` - Restore session
