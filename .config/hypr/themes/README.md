# Hyprland Themes

This directory contains theme files for Hyprland window manager that match the corresponding tmux themes.

## Available Themes

- `brown.conf` - Brown theme
- `catppuccin.conf` - Catppuccin Mocha theme
- `green.conf` - Green theme
- `indigo.conf` - Indigo theme
- `red.conf` - Red theme
- `swirl-rose.conf` - Swirl Rose theme
- `white.conf` - White theme

## How to Switch Themes

1. Edit `~/.config/hypr/hyprland.conf`
2. Change the `source` line in the "Theme configuration" section to point to your desired theme:

   ```bash
   # For green theme (default)
   source = ./themes/green.conf

   # For catppuccin theme
   source = ./themes/catppuccin.conf

   # For swirl rose theme
   source = ./themes/swirl-rose.conf

   # etc...
   ```

3. Reload Hyprland (usually `hyprctl reload` or restart Hyprland)

## Theme Variables

Each theme file defines two variables:

- `$active_border` - Color for active/focused window borders
- `$inactive_border` - Color for inactive/unfocused window borders

These variables are used in the main `hyprland.conf` configuration.
