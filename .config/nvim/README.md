# Neovim

A comprehensive Neovim setup with modern plugins, LSP support, and custom keybindings for efficient coding across multiple languages.

> [!NOTE]
> I barely live in Neovim these days. Most of my time is in other setups.
> This config is still very solid. If you want a one file Neovim that just works, this is it.

## Setup

1. **Copy the config:**

   ```bash
   cp .config/nvim/init.vim ~/.config/nvim/init.vim
   ```

2. **Start Neovim:**
   ```bash
   nvim
   ```

That's literally it! The config will auto-install vim-plug and all plugins on first launch.

## Features

### Plugin Ecosystem

- **vim-plug** - Plugin manager (auto-installs on first run)
- **coc.nvim** - Language Server Protocol support
- **Telescope** - Fuzzy finder and file browser
- **Treesitter** - Advanced syntax highlighting
- **NERDTree** - File explorer with git integration
- **lualine** - Status line with bubble theme
- **gitsigns** - Git diff indicators
- **Spectre** - Project-wide search and replace

### Language Support

- **TypeScript/JavaScript** - coc-tsserver with auto-imports
- **Python** - Ruff + MyPy + Jedi for completion and navigation
- **Rust** - rust-analyzer via coc
- **Go** - coc-go support
- **Prisma** - Prisma language server
- **Docker** - Docker language support
- **Web** - CSS, HTML, GraphQL
- **Config files** - TOML, YAML, JSON

### Themes

- **Catppuccin Mocha** (default with bubble status line)
- **Dracula**
- **Tokyo Night**
- **Gruvbox**
- **Neo Solarized**

## Keybindings & Operations

### Leader Key

- **Leader:** `,` (comma)
- **Placeholder navigation:** `,,` - Jump to next `<++>` placeholder

### File Operations

- **New file:** `<leader>nf` - Create new file with path prompt
- **New directory:** `<leader>nd` - Create new directory
- **Delete file:** `<leader>dd` - Move current file to trash
- **Rename file:** `<leader>mv` - Rename/move current file (updates imports)
- **File info:** `<leader>fa` - Show absolute path, `<leader>ft` - filename, `<leader>fr` - relative path
- **Copy relative path:** `<leader>fy` - Yank relative file path to clipboard
- **Change directory:** `<leader>cd` - cd to current file's directory, `<leader>gr` - cd to git root

### Navigation & Search

- **File browser:** `<leader>f` - Open Telescope file browser in current directory
- **Live grep:** `<leader>r` - Search text in project (ripgrep)
- **Grep string:** `<leader>R` - Search for word under cursor
- **Buffers:** `<leader>bl` - List buffers, `<Tab>/<S-Tab>` - Cycle buffers
- **Close buffer:** `Ctrl-x` - Delete current buffer

### LSP & Code Actions

- **Go to definition:** `gd` or `Ctrl-d`
- **Go to type definition:** `gy`
- **Go to implementation:** `gi`
- **Find references:** `gr` or `Ctrl-r`
- **Rename symbol:** `<leader>rn`
- **Code actions:** `<leader>ac`
- **Quick fix:** `<leader>qf`
- **Add missing imports:** `<leader>mi` (TypeScript/JavaScript)
- **Organize imports:** `<leader>oi` (TypeScript/JavaScript)

### File Explorer (NERDTree)

- **Toggle:** `<leader>n` - Toggle NERDTree (finds current file)
- **Resize:** `<leader>[` - Shrink, `<leader>]` - Grow
- **Equalize:** `<leader>=` - Equalize window sizes

### Project Search & Replace (Spectre)

- **Open search:** `<leader>sr` - Project-wide search and replace
- **Search word:** `<leader>sw` - Search word under cursor
- **File search:** `<leader>sf` - Search in current file

### Window Management

- **Split navigation:** `Ctrl-h/j/k/l` - Navigate between splits
- **Quickfix:** `<leader>qo` - Open, `<leader>qc` - Close, `]q/[q` - Next/prev

### Text Operations

- **VSCode-style copy/paste:**
  - `Ctrl-c` - Copy (line if no selection)
  - `Ctrl-v` - Paste from system clipboard (all modes)
- **Surround:** Use vim-surround plugin (`ys`, `cs`, `ds`)
- **Comment:** `gcc` - Toggle line comment, `gc` - Toggle visual selection

### UI Toggles

- **Buffer tabs:** `<leader>bt` - Toggle buffer tab line
- **UI elements:** `<leader>h` - Toggle status line, ruler, mode display
- **Spell check:** `<leader>o` - Toggle spell checking
- **Zen mode:** Custom zen mode setup available

### Git Integration

- **vim-fugitive** - Git commands (`:Gstatus`, `:Gcommit`, etc.)
- **vim-magit** - Git interface (`:Magit`)
- **gitsigns** - Line-by-line git status in gutter

## Language-Specific Features

### Python

- **LSP:** Ruff for linting, MyPy for type checking, Jedi for completion
- **Auto-formatting:** Ruff native server
- **Virtual environments:** Auto-detects `.venv`

### TypeScript/JavaScript

- **LSP:** coc-tsserver with auto-imports
- **Auto-updates:** Imports update when files are moved
- **JSX/TSX:** Full React support

### Rust

- **LSP:** rust-analyzer via coc
- **Auto-completion:** Full Rust language support

### Go

- **LSP:** coc-go for Go development

## Plugin Management

The config uses vim-plug with auto-installation. Key plugins:

- **coc.nvim** - LSP client with extensions for multiple languages
- **Telescope** - Fuzzy finding, file browsing, live grep
- **Treesitter** - Advanced syntax highlighting and parsing
- **lualine** - Status line with Catppuccin bubble theme
- **NERDTree** - File explorer with git status
- **vim-fugitive** - Git integration
- **Spectre** - Search and replace
- **vim-surround** - Text object manipulation
- **UltiSnips** - Snippet system

## Customization

### Themes

The config includes multiple color schemes. Switch themes by:

1. Opening vim
2. Running `:colorscheme <theme-name>`
3. Available: `catppuccin-mocha`, `dracula`, `tokyonight`, `gruvbox`, `neosolarized`

### coc.nvim Extensions

Additional language servers can be added to `g:coc_global_extensions` in `init.vim`.

### Keybindings

Most keybindings are configurable. The leader key is set to `,` - change `mapleader` at the top of `init.vim` to modify.

## Tips

- **Auto-completion:** Press `Ctrl-Space` to trigger completion manually
- **File operations:** Use `<leader>nf` and `<leader>nd` for quick file/directory creation
- **Search & replace:** Spectre provides visual feedback for project-wide changes
- **Git integration:** Multiple git plugins available - use what works best for your workflow
- **Performance:** Treesitter provides fast, accurate syntax highlighting
- **VSCode-like editing:** Ctrl-c/Ctrl-v work like modern editors
- **Placeholders:** Use `,,` to jump between `<++>` placeholders in templates

