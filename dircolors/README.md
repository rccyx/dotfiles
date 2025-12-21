# dircolors Configuration & Themes

A collection of LS_COLORS themes that make your `ls` command output beautiful and organized with color-coded file types.

## Setup

1. **Copy the themes directory:**

   ```bash
   cp -r dircolors/ ~/dircolors/
   ```

2. **Add to your shell config** (`.bashrc`, `.zshrc`, etc.):

   ```bash
   # Load dircolors theme
   eval "$(dircolors ~/dircolors/catppuccin-mocha)"
   ```

3. **Or use the main config file:**

   ```bash
   cp .dircolors ~/.dircolors
   # Then add to your shell config:
   eval "$(dircolors ~/.dircolors)"
   ```

4. **Reload your shell:**
   ```bash
   source ~/.zshrc  # or your shell config
   ```

**Available themes:**

- `catppuccin-mocha` - Catppuccin Mocha colors (warm, earthy tones)
- `swirl-rose` - Rose/pink theme (soft and elegant)
- `tokyonight` - Tokyo Night theme (cool blues and purples)
- `white` - Monochrome white theme (clean and minimal)
