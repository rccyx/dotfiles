### Audio & Media

- **activate-mic.zsh**: Installs and configures PipeWire audio stack, disables legacy PulseAudio, unmutes microphones via ALSA, sets a default PipeWire source, and verifies the setup. Includes a quick mic test command.

  - Usage: `./activate-mic.zsh`
  - Output: Logs progress and ends with verification steps.

- **activate-speakers.zsh**: Idempotent script to auto-switch between headphones and speakers on PipeWire/PulseAudio. Detects headphone availability and sets the appropriate port.

  - Usage: `./activate-speakers.zsh`
  - Output: Echoes the switch (e.g., "Switching to headphones...").

- **enable-screen-share.zsh**: Configures PipeWire and xdg-desktop-portal-wlr for screen sharing in Hyprland/Wayland. This is a known problem on Debian based distros, where you can't share your screen on Google Meet, this solves it.Installs required packages, enables user units, writes Chrome/Chromium flags for Wayland and WebRTC, and verifies the stack.

  - Usage: `./enable-screen-share.zsh`
  - Output: Logs installation and ends with browser launch instructions.

- **fix-voaster-sink.zsh**: Sets the Vocaster One audio sink as the default in PipeWire and moves active streams to it.
  - Usage: `./fix-voaster-sink.zsh` (or alias it as `vocaster-default`).
  - Output: Lists sinks and confirms the switch.

### Hardware Fixes

- **fix-bluetooth.zsh**: Bluetooth fix for Debian Trixie. Installs packages, configures BlueZ, disables autosuspend, restarts services, and includes a Wi-Fi watchdog to restore connections if disrupted. Ends with diagnostics.

  - Usage: `./fix-bluetooth.zsh`
  - Output: Step-by-step logs, including kernel messages and device scans.

- **fix-wifi-firmware-patch.zsh**: Patches Intel WiFi firmware (iwlwifi) by downloading the latest from kernel.org, installing it, applying stability options, and reloading modules. Includes diagnostics.
  - Usage: `./fix-wifi-firmware-patch.zsh`
  - Output: Logs download/install and kernel log tail.

### System Configuration

- **enable-corepack.zsh**: Enables Node.js Corepack and activates the latest pnpm package manager.

  - Usage: `./enable-corepack.zsh`
  - Output: None (runs silently).

- **enable-mac-like-screenshots.zsh**: Creates a `shot-mac` script for macOS-style screenshots (selection, save to file, copy to clipboard, annotate with swappy). Handles color filters to avoid tinting.

  - Usage: `./enable-mac-like-screenshots.zsh`
  - Output: None (creates `~/.local/bin/shot-mac`).

- **fix-time.zsh**: Interactive timezone and NTP server setup using fzf. Installs dependencies, sets timezone/RTC, writes systemd-timesyncd config, and forces a resync.

  - Usage: `./fix-time.zsh`
  - Output: Prompts for selections and shows final status.

- **gtk-shutp.zsh**: Sets up a GTK cursor theme (default: Bibata-Modern-Ice) with aliases for missing cursors, exports environment vars, and refreshes caches.
  - Usage: `./gtk-shutp.zsh [theme] [size]`
  - Example: `./gtk-shutp.zsh Adwaita 32`

### Development & Tools

- **fix-zsh.zsh**: Reinstalls Oh My Zsh (clones fresh, preserves custom dir) and adds plugins: zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions.

  - Usage: `./fix-zsh.zsh`
  - Output: None (executes `zsh` at end).

- **install-hyprland-qtutils.zsh**: Builds and installs hyprland-qtutils (Hyprland Qt utilities) from GitHub.

  - Usage: `./install-hyprland-qtutils.zsh` (or alias as `hypr_qtutils`).
  - Output: Logs to `~/.local/share/hypr_qtutils.log`.

- **rust-analyzer-install.zsh**: Installs Rust Analyzer via rustup.
  - Usage: `./rust-analyzer-install.zsh`
  - Output: None.

### Clipboard & Notifications

- **setup-clipboard.zsh**: Sets up clipvault (clipboard manager) with watchers, pickers (fzf/wofi), pruning, and Hyprland integration (autostart, Super+X bind).

  - Usage: `./setup-clipboard.zsh setup | destroy | status | reset`
  - Env Vars: `CLIP_CAP=200`, `CLEAR_DAYS=3`, etc.
  - Output: Logs setup and provides usage hints.

- **setup-notify-battery.zsh**: I don't use topbars, so I rely on notifications, This sets up idempotent battery notifications via systemd timer. Checks levels on discharge, sends notifications with cooldowns.

  - Usage: `./setup-notify-battery.zsh setup | destroy | status | test <level> | test-sweep`
  - Env Vars: `THRESHOLDS="50 30 20 10 5"`, `COOLDOWN_MIN=20`.
  - Waybar Integration: Not included (add manually).

- **setup-notify-heat.zsh**: CPU temperature notifications with smoothing for Waybar, sustain gate, and cooldowns. Sources from sysfs or sensors.
  - Usage: `./setup-notify-heat.zsh setup | destroy | status | test <C> | test-sweep`
  - Env Vars: `HEAT_THRESHOLDS="70 80 85"`, `HEAT_COOLDOWN_MIN=15`, `HEAT_SUSTAIN_SEC=10`.
  - Waybar Example: `"custom/cpu_temp": { "exec": "~/.local/bin/cpu-temp", "interval": 2, "format": " {}°C" }`.

### Android Integration

- **setup-droid.zsh**: Installs Waydroid, downloads WhatsApp APK, sets up launcher/desktop entry for WhatsApp-on-Linux.
  - Usage: `./setup-droid.zsh setup | open | status | destroy`
  - Output: Logs progress; use `wh` to launch after setup.
