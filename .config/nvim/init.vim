" =========================================================
"                 LEADER & BOOTSTRAP SETUP
" ==========================================================
let mapleader = ","

" Auto setup all the plugins on first launch (vim-plug bootstrap)
if ! filereadable(system('echo -n "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/autoload/plug.vim"'))
    echo "Downloading junegunn/vim-plug to manage plugins..."
    silent !mkdir -p ${XDG_CONFIG_HOME:-$HOME/.config}/nvim/autoload/
    silent !curl "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim" > ${XDG_CONFIG_HOME:-$HOME/.config}/nvim/autoload/plug.vim
    autocmd VimEnter * PlugInstall
endif

" Custom mapping for quick text placeholder navigation
map ,, :keepp /<++><CR>ca<
imap ,, <esc>:keepp /<++><CR>ca<

" ==========================================================
"                   BASIC EDITOR SETTINGS
" ==========================================================
set shell=/usr/bin/zsh
set shellredir=>%s\ 2>&1
set encoding=UTF-8
set number
set relativenumber
set autoindent
set shiftwidth=4
set smarttab
set title
" set bg=light
set background=dark
" only set guioptions if it exists (avoids E518 on nvim)
if exists("&guioptions")
  set guioptions+=a
endif
set mouse=a
set nohlsearch
set clipboard+=unnamedplus
set noshowmode
set noruler
set laststatus=0
set noshowcmd
set nocompatible
set showtabline=0
nnoremap c "_c
filetype plugin on
syntax on

" ==== Python host for Neovim ====
if executable('/usr/bin/python3')
  let g:python3_host_prog = '/usr/bin/python3'
endif

" ==========================================================
"                      PLUGIN SECTION
" ==========================================================
call plug#begin(system('echo -n "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/plugged"'))

" ----- Theme Plugins -----
Plug 'Mofiqul/dracula.nvim'
Plug 'catppuccin/nvim', { 'as': 'catppuccin' }
Plug 'folke/tokyonight.nvim'
Plug 'morhetz/gruvbox'
Plug 'svrana/neosolarized.nvim'
Plug 'nvim-lualine/lualine.nvim'

" ----- Helper Plugins -----
Plug 'nvim-lua/plenary.nvim'
Plug 'tpope/vim-surround'
Plug 'preservim/nerdtree'
Plug 'junegunn/goyo.vim'
Plug 'jreybert/vimagit'
Plug 'vimwiki/vimwiki'
Plug 'tpope/vim-commentary'
Plug 'ryanoasis/vim-devicons'
Plug 'scrooloose/nerdcommenter'
Plug 'sheerun/vim-polyglot'
Plug 'tpope/vim-fugitive'
" REMOVED: Plug 'davidhalter/jedi-vim'
Plug 'vim-scripts/indentpython.vim'
Plug 'Xuyuanp/nerdtree-git-plugin'
Plug 'tiagofumo/vim-nerdtree-syntax-highlight'
Plug 'PhilRunninger/nerdtree-visual-selection'
Plug 'SirVer/ultisnips' | Plug 'honza/vim-snippets'
Plug 'scrooloose/nerdcommenter', { 'on':  'NERDTreeToggle' }
Plug 'tpope/vim-fireplace', { 'for': 'clojure' }
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'jiangmiao/auto-pairs'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'nvim-treesitter/nvim-treesitter-textobjects'
Plug 'wbthomason/packer.nvim'
Plug 'onsails/lspkind-nvim'
Plug 'neovim/nvim-lspconfig'
Plug 'jose-elias-alvarez/null-ls.nvim'
Plug 'MunifTanjim/prettier.nvim'
Plug 'williamboman/mason.nvim'
Plug 'williamboman/mason-lspconfig.nvim'
Plug 'glepnir/lspsaga.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-telescope/telescope-file-browser.nvim'
Plug 'windwp/nvim-autopairs'
Plug 'windwp/nvim-ts-autotag'
Plug 'norcalli/nvim-colorizer.lua'
" REMOVED: Plug 'akinsho/nvim-bufferline.lua'
Plug 'lewis6991/gitsigns.nvim'
Plug 'dinhhuy258/git.nvim'
Plug 'folke/zen-mode.nvim'
Plug 'iamcco/markdown-preview.nvim'

" ----- Language-specific Plugins -----
Plug 'ap/vim-css-color'
Plug 'prisma/vim-prisma'
Plug 'pangloss/vim-javascript'
Plug 'leafgarland/typescript-vim'
Plug 'maxmellon/vim-jsx-pretty'
Plug 'jparise/vim-graphql'
Plug 'rust-lang/rust.vim'
Plug 'cespare/vim-toml', {'branch': 'main'}
Plug 'stephpy/vim-yaml'
Plug 'plasticboy/vim-markdown'

" ----- LSP/Autocomplete -----
Plug 'neoclide/coc.nvim', {'branch': 'release'}

" ----- Added: file ops + sudo + project replace -----
Plug 'tpope/vim-eunuch'          " :Rename :Delete :Move :Mkdir
Plug 'lambdalisue/suda.vim'      " w!! to write root-owned files
Plug 'nvim-pack/nvim-spectre'    " ripgrep-powered project replace

call plug#end()

" Bridge Treesitter parser names to filetypes used by plugins
lua << EOF
pcall(function()
  vim.treesitter.language.register('tsx', 'typescriptreact')
  vim.treesitter.language.register('javascript', 'javascriptreact')
end)
EOF

" ==========================================================
"                      PLUGIN CONFIG
" ==========================================================
set termguicolors
set laststatus=3

lua << EOF
-- Catppuccin bubble lualine
local ok, palettes = pcall(require, "catppuccin.palettes")
local pal
if ok and palettes and type(palettes.get_palette) == "function" then
  pal = palettes.get_palette("mocha")
else
  pal = {
    rosewater = "#f5e0dc", flamingo = "#f2cdcd", pink = "#f5c2e7", mauve = "#cba6f7",
    red = "#f38ba8", maroon = "#eba0ac", peach = "#fab387", yellow = "#f9e2af",
    green = "#a6e3a1", teal = "#94e2d5", sky = "#89dceb", sapphire = "#74c7ec",
    blue = "#89b4fa", lavender = "#b4befe",
    text = "#cdd6f4", subtext1 = "#bac2de", overlay0 = "#6c7086",
    surface0 = "#313244", base = "#1e1e2e", mantle = "#181825", crust = "#11111b",
  }
end

local bubbles_theme = {
  normal = {
    a = { fg = pal.crust, bg = pal.lavender, gui = "bold" },
    b = { fg = pal.text,  bg = pal.surface0 },
    c = { fg = pal.subtext1, bg = pal.base },
  },
  insert  = { a = { fg = pal.crust, bg = pal.green,   gui = "bold" } },
  visual  = { a = { fg = pal.crust, bg = pal.mauve,   gui = "bold" } },
  replace = { a = { fg = pal.crust, bg = pal.red,     gui = "bold" } },
  command = { a = { fg = pal.crust, bg = pal.peach,   gui = "bold" } },
  inactive = {
    a = { fg = pal.overlay0, bg = pal.mantle },
    b = { fg = pal.overlay0, bg = pal.mantle },
    c = { fg = pal.overlay0, bg = pal.mantle },
  },
}

require("lualine").setup({
  options = {
    theme = bubbles_theme,
    icons_enabled = true,
    component_separators = { left = "", right = "" },
    section_separators   = { left = "", right = "" },
    globalstatus = true,
    disabled_filetypes = { "NERDTree", "packer" },
  },
  sections = {
    lualine_a = { { "mode", separator = { left = "" }, right_padding = 2 } },
    lualine_b = { "branch", "diff", "diagnostics" },
    lualine_c = { { "filename", path = 0, file_status = false, newfile_status = false,
      fmt = function(name)
        local max = 15
        if #name <= max then return name end
        local ext = name:match("(%.[^%.]+)$") or ""
        local keep = max - #ext - 1
        if keep < 1 then return name:sub(1, max - 1) .. "…" end
        return name:sub(1, keep) .. "…" .. ext
      end } },
    lualine_x = { "encoding", "fileformat", "filetype" },
    lualine_y = { "progress" },
    lualine_z = { { "location", separator = { right = "" }, left_padding = 2 } },
  },
  inactive_sections = { lualine_a = { { "filename", separator = { left = "", right = "" } } } },
  extensions = { "fzf", "quickfix", "fugitive" },
})
EOF

set laststatus=2

lua << EOF
require('lualine').setup({
  options = { theme = 'auto', icons_enabled = true, component_separators = '', section_separators = '' },
  extensions = { 'fzf', 'quickfix', 'fugitive' }
})
EOF

silent! nunmap <leader>bl
nnoremap <silent> <leader>bl <cmd>Telescope buffers sort_lastused=true ignore_current_buffer=true<cr>
" REMOVED: nnoremap <silent> <leader>bp :BufferLinePick<CR>

let g:ash_showtabline = 0
function! ToggleBufferTabs()
  if g:ash_showtabline == 2 | let g:ash_showtabline = 0 | else | let g:ash_showtabline = 2 | endif
  execute 'set showtabline=' . g:ash_showtabline
endfunction
nnoremap <silent> <leader>bt :call ToggleBufferTabs()<CR>

let NERDTreeShowHidden=1
let NERDTreeQuitOnOpen=1

let g:WebDevIconsUnicodeDecorateFolderNodes = 1
let g:WebDevIconsUnicodeDecorateFolderNodeDefaultSymbol = '#'
let g:WebDevIconsUnicodeDecorateFileNodesExtensionSymbols = {}
let g:WebDevIconsUnicodeDecorateFileNodesExtensionSymbols['nerdtree'] = '#'

let g:AutoPairsMapCR = 0

" ===== Coc extensions =====
let g:coc_global_extensions = [
\ 'coc-tsserver',
\ '@yaegassy/coc-ruff',
\ '@yaegassy/coc-mypy',
\ 'coc-rust-analyzer',
\ 'coc-go',
\ 'coc-docker'
\ ]
let g:coc_global_extensions += ['coc-jedi']

" TS/JS settings including auto update imports on file move
let g:coc_user_config = extend(get(g:, 'coc_user_config', {}), {
\   'typescript.suggest.autoImports': v:true,
\   'javascript.suggest.autoImports': v:true,
\   'typescript.preferences.importModuleSpecifier': 'relative',
\   'javascript.preferences.importModuleSpecifier': 'relative',
\   'typescript.updateImportsOnFileMove.enabled': 'always',
\   'javascript.updateImportsOnFileMove.enabled': 'always',
\   'suggest.noselect': v:false
\ }, 'force')

" Prisma language server
if executable('prisma-language-server')
  let g:coc_user_config = extend(get(g:, 'coc_user_config', {}), {
  \   'languageserver': {
  \     'prisma': {
  \       'command': 'prisma-language-server',
  \       'args': ['--stdio'],
  \       'filetypes': ['prisma'],
  \       'rootPatterns': ['schema.prisma'],
  \       'trace.server': 'verbose'
  \     }
  \   }
  \ }, 'force')
endif

" ===== Python via Ruff + mypy only, Jedi for nav/rename =====
if !exists('g:coc_node_path')
  let s:nodes = glob('~/.nvm/versions/node/v20*/bin/node', 1, 1)
  if len(s:nodes) > 0 | let g:coc_node_path = s:nodes[0] | endif
endif

let g:coc_user_config = extend(get(g:, 'coc_user_config', {}), {
\  'python.venvPath': '.',
\  'python.venv': '.venv',
\  'python.analysis.autoImportCompletions': v:false,
\  'ruff.enable': v:true,
\  'ruff.nativeServer': v:true,
\  'ruff.path': ['.venv/bin/ruff', 'ruff'],
\  'ruff.interpreter': ['.venv/bin/python'],
\  'mypy-type-checker.enable': v:true,
\  'mypy-type-checker.useDmypy': v:true,
\  'mypy-type-checker.cwd': '${workspaceFolder}',
\  'mypy-type-checker.venvPath': '.',
\  'mypy-type-checker.venv': '.venv',
\  'mypy-type-checker.executable': '.venv/bin/mypy',
\  'jedi.enable': v:true
\}, 'force')

function! s:project_root() abort
  let l:gitdir = finddir('.git', expand('%:p:h').';')
  return empty(l:gitdir) ? getcwd() : fnamemodify(l:gitdir, ':h')
endfunction
function! s:activate_venv() abort
  let l:root = s:project_root()
  for l:name in ['.venv', 'venv']
    let l:py = l:root.'/'.l:name.'/bin/python'
    if filereadable(l:py)
      let g:python3_host_prog = l:py
      let $VIRTUAL_ENV = l:root.'/'.l:name
      let $PATH = l:root.'/'.l:name.'/bin:'.$PATH
      break
    endif
  endfor
endfunction
autocmd VimEnter,BufEnter *.py call s:activate_venv()

" ===== Telescope including file-browser actions =====
lua << EOF
local telescope = require("telescope")
local actions = require("telescope.actions")
local ok_fb, fb_actions = pcall(require, "telescope._extensions.file_browser.actions")

telescope.setup({
  defaults = {
    vimgrep_arguments = { "rg", "--hidden", "--glob", "!.git/*", "--no-heading", "--with-filename", "--line-number", "--column", "--smart-case" },
    sorting_strategy = "ascending",
    layout_config = { prompt_position = "top" },
    mappings = { i = { ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist }, n = { ["q"] = actions.close } },
  },
  pickers = { live_grep = { only_sort_text = true }, grep_string = { only_sort_text = true } },
  extensions = ok_fb and {
    file_browser = {
      hijack_netrw = true,
      grouped = true,
      hidden = true,
      respect_gitignore = false,
      mappings = {
        ["n"] = { ["a"] = fb_actions.create, ["r"] = fb_actions.rename, ["d"] = fb_actions.remove, ["m"] = fb_actions.move, ["y"] = fb_actions.copy },
        ["i"] = { ["<C-n>"] = fb_actions.create, ["<C-r>"] = fb_actions.rename, ["<C-d>"] = fb_actions.remove, ["<C-m"] = fb_actions.move, ["<C-y>"] = fb_actions.copy },
      },
    },
  } or {},
})
pcall(function() telescope.load_extension("file_browser") end)
EOF

" ===== Theme =====
lua << EOF
require("catppuccin").setup({
  flavour = "mocha",
  integrations = { bufferline = true, treesitter = true, coc_nvim = true, nvimtree = true, native_lsp = { enabled = true } }
})

_G.ForceTransparent = function()
  local groups = {
    "Normal",
    "NormalFloat",
    "SignColumn",
    "LineNr",
    "CursorLineNr",
    "Folded",
    "MsgArea",
    "ColorColumn",
    "WinSeparator",
  }

  for _, name in ipairs(groups) do
    vim.api.nvim_set_hl(0, name, { bg = "NONE" })
  end
end

vim.cmd.colorscheme("catppuccin")
ForceTransparent()

local themes = {
  "catppuccin",
  "dracula",
  "gruvbox",
  "tokyonight",
  "neosolarized",
}

local i = 1

_G.CycleTheme = function()
  i = i % #themes + 1
  local t = themes[i]
  vim.cmd("colorscheme " .. t)
  ForceTransparent()
  print("theme: " .. t)
end
EOF

" Theme toggle
nnoremap <leader>th :lua CycleTheme()<CR>

" ==========================================================
"                  KEYBINDINGS & COMMANDS
" ==========================================================
silent! nunmap <C-r> | silent! vunmap <C-r> | silent! iunmap <C-r>
silent! nunmap <C-u> | silent! vunmap <C-u> | silent! iunmap <C-u>
silent! nunmap <C-z> | silent! vunmap <C-z> | silent! iunmap <C-z>
silent! nunmap <C-s> | silent! vunmap <C-s> | silent! iunmap <C-s>
silent! nunmap <C-q> | silent! vunmap <C-q> | silent! iunmap <C-q>
" Ensure Ctrl+A is not mapped by this config
silent! nunmap <C-a> | silent! vunmap <C-a> | silent! iunmap <C-a>

nnoremap <C-z> u
inoremap <C-z> <C-o>u
vnoremap <C-z> <Esc>u

nnoremap <C-S-z> <C-r>
inoremap <C-S-z> <C-o><C-r>
vnoremap <C-S-z> <Esc><C-r>
nnoremap <C-y> <C-r>
inoremap <C-y> <C-o><C-r>
vnoremap <C-y> <Esc><C-r>

nnoremap <C-s> :update<CR>
inoremap <C-s> <C-o>:update<CR>
vnoremap <C-s> <Esc>:update<CR>gv

nnoremap <C-p> :stop<CR>
inoremap <C-p> <C-o>:stop<CR>
vnoremap <C-p> <Esc>:stop<CR>

nnoremap <C-q> :q!<CR>
inoremap <C-q> <C-o>:q!<CR>
vnoremap <C-q> <Esc>:q!<CR>

function! CycleBufNext()
  if exists(':BufferLineCycleNext') && &showtabline > 0 | execute 'BufferLineCycleNext' | else | bnext | endif
endfunction
function! CycleBufPrev()
  if exists(':BufferLineCyclePrev') && &showtabline > 0 | execute 'BufferLineCyclePrev' | else | bprevious | endif
endfunction
nnoremap <silent> <Tab>   :call CycleBufNext()<CR>
nnoremap <silent> <S-Tab> :call CycleBufPrev()<CR>
" REMOVED: nnoremap <silent> <leader>bp :BufferLinePick<CR>

nnoremap <leader>bl :ls<CR>:b<Space>
inoremap <silent> <C-x> <C-o>:bd<CR>
vnoremap <silent> <C-x> <Esc>:bd<CR>
nnoremap <silent> <C-x> :bd<CR>

nnoremap <leader>fa :echo expand('%:p')<CR>
nnoremap <leader>ft :echo expand('%:t')<CR>
nnoremap <leader>fr :echo fnamemodify(expand('%'), ':.')<CR>
nnoremap <leader>fy :let @+ = fnamemodify(expand('%'), ':.') \| echo 'yanked relative file path'<CR>
nnoremap <leader>cd :lcd %:p:h<CR>
nnoremap <leader>gr :execute 'cd ' . systemlist('git rev-parse --show-toplevel')[0]<CR>

function! s:rel_to_git_root()
  let root = systemlist('git rev-parse --show-toplevel')[0]
  return substitute(expand('%:p'), '^'.escape(root, '\'), '', '')[1:]
endfunction

nnoremap <leader>fg :echo <SID>rel_to_git_root()<CR>

nnoremap <leader>f :Telescope file_browser path=%:p:h<CR>

nnoremap <silent> <leader>qo :copen<CR>
nnoremap <silent> <leader>qc :cclose<CR>
nnoremap <silent> ]q :cnext<CR>
nnoremap <silent> [q :cprev<CR>

map <C-h> <C-w>h
map <C-j> <C-w>j
map <C-k> <C-w>k
map <C-l> <C-w>l

" Coc navigation
nmap <leader>ac  <Plug>(coc-codeaction)
nmap <leader>qf  <Plug>(coc-fix-current)
nmap <silent> gd <Plug>(coc-definition)
" Ctrl+A = jump back (reverse of Ctrl+D)
nnoremap <C-a> <C-o>
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)
nnoremap <C-d> <Plug>(coc-definition)
" REMOVED: nnoremap <C-a> <C-o>
nnoremap <silent> <C-r> <Plug>(coc-references)
nmap <leader>rn  <Plug>(coc-rename)

map <leader>o :setlocal spell! spelllang=en_us<CR>
nnoremap <leader>mi :call CocActionAsync('codeAction', '', ['source.addMissingImports.ts'])<CR>
nnoremap <leader>oi :call CocActionAsync('runCommand', 'editor.action.organizeImport')<CR>

" NERDTree tweaks
let g:NERDTreeWinPos = 'left'
let g:NERDTreeWinSize = 28
let g:NERDTreeMinimalUI = 1
let g:NERDTreeDirArrows = 1
let g:NERDTreeShowHidden = 1
augroup NerdTreeTweak
  autocmd!
  autocmd FileType nerdtree setlocal nonumber norelativenumber nocursorline signcolumn=no
  autocmd FileType nerdtree setlocal winfixwidth
augroup END
function! ToggleNERDTreeFind()
  if exists("t:NERDTreeBufName") && bufwinnr(t:NERDTreeBufName) != -1
    NERDTreeClose
  else
    execute 'NERDTreeFind'
    execute 'vertical resize ' . get(g:,'NERDTreeWinSize',28)
  endif
endfunction
nnoremap <leader>n :call ToggleNERDTreeFind()<CR>
nnoremap <silent> <leader>[ :let g:NERDTreeWinSize=max([16, get(g:,'NERDTreeWinSize',28)-4]) \| execute 'vertical resize ' . g:NERDTreeWinSize<CR>
nnoremap <silent> <leader>] :let g:NERDTreeWinSize=get(g:,'NERDTreeWinSize',28)+4 \| execute 'vertical resize ' . g:NERDTreeWinSize<CR>
nnoremap <silent> <leader>= :wincmd =<CR>

cnoreabbrev ff FZF!

inoremap <silent><expr> <C-Space> coc#refresh()
inoremap <silent><expr> <Tab> pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <silent><expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
inoremap <silent><expr> <CR> pumvisible() ? coc#pum#confirm() : "\<CR>"

nnoremap S :%s//g<Left><Left>
nnoremap <silent> <leader>r <cmd>Telescope live_grep<cr>
nnoremap <silent> <leader>R <cmd>Telescope grep_string<cr>

" ===== Added: fast file ops inside Neovim =====
let g:suda_smart_edit = 1
cnoreabbrev w!! SudaWrite

function! s:NewFilePrompt() abort
  let base = expand('%:p:h')
  let path = input('New file path: ', base.'/','file')
  if empty(path) | return | endif
  call mkdir(fnamemodify(path, ':h'), 'p')
  execute 'edit' fnameescape(path)
  if empty(glob(path)) | write | endif
endfunction
function! s:NewDirPrompt() abort
  let base = expand('%:p:h')
  let path = input('New directory: ', base.'/','dir')
  if empty(path) | return | endif
  call mkdir(path, 'p')
  echo 'created ' . path
endfunction
nnoremap <leader>nf :call <SID>NewFilePrompt()<CR>
nnoremap <leader>nd :call <SID>NewDirPrompt()<CR>

function! s:DeleteCurrentFileToTrash() abort
  let f = expand('%:p')
  if empty(f) || !filereadable(f) | echo 'no file on disk' | return | endif
  if confirm('trash ' . f . '?', "&Yes\n&No", 2) != 1 | return | endif
  if executable('trash-put')
    call system(['trash-put', f])
  elseif executable('gio')
    call system(['gio','trash', f])
  else
    call delete(f)
  endif
  bdelete!
endfunction
nnoremap <leader>dd :call <SID>DeleteCurrentFileToTrash()<CR>

" LSP file rename that updates TS/JS imports via tsserver
function! s:RenameCurrentFile() abort
  try
    if exists('*CocActionAsync')
      call CocActionAsync('runCommand','workspace.renameCurrentFile')
      return
    endif
  catch /.*/
  endtry
  let old = expand('%:p')
  let new = input('New path: ', old, 'file')
  if empty(new) || new == old | return | endif
  call mkdir(fnamemodify(new, ':h'), 'p')
  execute 'saveas' fnameescape(new)
  call delete(old)
endfunction
nnoremap <leader>mv :call <SID>RenameCurrentFile()<CR>

" ===== Added: Spectre project replace =====
nnoremap <leader>sr :lua require('spectre').open()<CR>
nnoremap <leader>sw :lua require('spectre').open_visual({select_word=true})<CR>
vnoremap <leader>sw :lua require('spectre').open_visual()<CR>
nnoremap <leader>sf :lua require('spectre').open_file_search({select_word=true})<CR>

" ===== VSCode-like copy/paste (system clipboard) =====
" Copy: Ctrl+C copies selection; no selection copies current line
xnoremap <C-c> "+y
nnoremap <C-c> "+yy
inoremap <C-c> <Esc>"+yy

" Paste: Ctrl+V pastes from system clipboard in all modes
nnoremap <C-v> "+p
xnoremap <C-v> "+p
inoremap <C-v> <C-r>+
cnoremap <C-v> <C-r>+

" Optional: enable shift-select behavior similar to editors
set keymodel+=startsel

" ==========================================================
"                  AUTOCOMMANDS & FUNCTIONS
" ==========================================================
autocmd BufNewFile,BufRead *.tsx set filetype=typescriptreact
autocmd BufNewFile,BufRead *.jsx set filetype=javascriptreact

autocmd BufWritePre * let currPos = getpos(".")
autocmd BufWritePre * %s/\s\+$//e
autocmd BufWritePre * %s/\n\+\%$//e
autocmd BufWritePre * %s/\%$/\r/e
autocmd BufWritePre *neomutt* %s/^--$/-- /e
autocmd BufWritePre * cal cursor(currPos[1], currPos[2])

autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

augroup TransparentBG
  autocmd!
  autocmd ColorScheme * lua ForceTransparent()
augroup END

if &diff
    highlight! link DiffText MatchParen
endif

let s:hidden_all = 0
function! ToggleHiddenAll()
    if s:hidden_all == 0
        let s:hidden_all = 1
        set noshowmode
        set noruler
        set laststatus=0
        set noshowcmd
    else
        let s:hidden_all = 0
        set showmode
        set ruler
        set laststatus=2
        set showcmd
    endif
endfunction
nnoremap <leader>h :call ToggleHiddenAll()<CR>

" ==========================================================
"                  MISC VISUAL SETTINGS
" ==========================================================
hi Normal guibg=NONE
