# Hyprland

- SUPER is the main modifier
- kitty is the terminal
- wofi is the launcher
- Chrome runs in app mode for “native” webapps
- Dwindle layout everywhere
- Rounded corners, subtle blur, clean borders
- No bar though, waybar is the default and I don't use it anymore.

## Autostart

Everything loads once:

- hyprpaper
- mako
- swww + waypaper
- cliphist + extra watchers
- pavucontrol (hidden)
- blueman
- my own scripts for clipboard, whisper, screenshots, checkout the [scripts](/scripts/) directory.

## Keybind map

- ALT+Enter → kitty
- SUPER+Space → wofi launcher
- ALT+W/O/S/E/C/F/G → whisper, obsidian, spotify, code, cursor, files, chrome
- ALT+SHIFT+(C/G/Y/S) → calendar, chatgpt, youtube, soundcloud
- PRINT → screenshot
- SUPER+X → clipboard picker, (@see scripts)
- SUPER+(arrows) → focus
- SUPER+SHIFT+(arrows) → move windows
- CTRL+ALT+(arrows) → workspace nav
- SUPER+numbers → workspaces
- SUPER+CTRL+L → lock

## Style

- gaps_in 6
- gaps_out 18
- border 2px
- white active border
- catppuccin grey inactive
- blur enabled
- opacity tuning for browsers and terminals

## Window Rules

- terminals at 0.97
- browsers, editors, obsidian at 0.9
