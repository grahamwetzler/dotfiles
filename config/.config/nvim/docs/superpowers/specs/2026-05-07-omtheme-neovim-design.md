# omtheme Neovim Colorscheme — Design Spec

**Date:** 2026-05-07

## Overview

Port the omtheme VS Code theme (dracula variant, darker background) to Neovim as a self-contained Lua module inside the existing `~/.config/nvim` config. No external plugin host; loaded directly via lazy.nvim's `dir` option.

## File Structure

```
lua/omtheme/
├── init.lua      -- entry point: sets options, clears highlights, calls groups.setup(palette)
├── palette.lua   -- returns color table with all named hex values
└── groups.lua    -- setup(p) function: defines all nvim_set_hl calls
```

`plugins/init.lua` replaces the tokyonight entry with a lazy.nvim spec pointing at `vim.fn.stdpath("config")`.

## Palette

Sourced from `src/dracula.yml` in the omtheme repo:

| Name        | Hex       | Role                          |
|-------------|-----------|-------------------------------|
| bg          | #13141f   | editor background             |
| bg_dark     | #12131d   | darker panels                 |
| bg_light    | #181928   | sidebars, float backgrounds   |
| bg_lighter  | #282A36   | selection, inactive           |
| fg          | #F8F8F2   | default foreground            |
| selection   | #44475A   | visual selection              |
| comment     | #6272A4   | comments, inactive UI         |
| cyan        | #8BE9FD   | types, search highlights      |
| green       | #50FA7B   | strings, added git lines      |
| orange      | #FFB86C   | constants, changed lines      |
| pink        | #FF79C6   | functions, keywords           |
| purple      | #BD93F9   | keywords, builtins, normal mode|
| red         | #FF5555   | errors, deleted lines         |
| yellow      | #F1FA8C   | variables, warnings           |
| white       | #FFFFFF   | bright foreground             |

## Highlight Groups

### Editor UI
Normal, NormalFloat, NormalNC, Cursor, CursorLine, CursorLineNr, LineNr, SignColumn, ColorColumn, VertSplit, WinSeparator, StatusLine, StatusLineNC, Pmenu, PmenuSel, PmenuSbar, PmenuThumb, Search, IncSearch, Visual, VisualNOS, Folded, FoldColumn, MatchParen, ModeMsg, MoreMsg, Question, ErrorMsg, WarningMsg, NonText, SpecialKey, WildMenu, TabLine, TabLineSel, TabLineFill, EndOfBuffer, Directory

### Syntax (legacy + treesitter @-groups)
Comment, Constant, String, Character, Number, Boolean, Float, Identifier, Function, Statement, Conditional, Repeat, Label, Operator, Keyword, Exception, PreProc, Type, Special, Underlined, Error, Todo — plus corresponding `@comment`, `@string`, `@function`, `@keyword`, `@type`, `@variable`, `@constant`, `@operator`, `@punctuation`, `@parameter`, `@field`, `@constructor`, `@tag` treesitter variants.

### Diagnostics & LSP
DiagnosticError, DiagnosticWarn, DiagnosticInfo, DiagnosticHint, DiagnosticUnderlineError, DiagnosticUnderlineWarn, DiagnosticUnderlineInfo, DiagnosticUnderlineHint, LspReferenceText, LspReferenceRead, LspReferenceWrite

### Plugins
- **Telescope:** TelescopeBorder, TelescopePromptBorder, TelescopeResultsBorder, TelescopePreviewBorder, TelescopeMatching, TelescopeSelection
- **NeoTree:** NeoTreeNormal, NeoTreeNormalNC, NeoTreeIndentMarker, NeoTreeGitAdded, NeoTreeGitModified, NeoTreeGitDeleted, NeoTreeGitUntracked
- **Gitsigns:** GitSignsAdd, GitSignsChange, GitSignsDelete, GitSignsAddNr, GitSignsChangeNr, GitSignsDeleteNr
- **nvim-cmp:** CmpItemAbbr, CmpItemAbbrMatch, CmpItemKind, CmpItemMenu, CmpItemAbbrDeprecated, PmenuSel (shared)
- **WhichKey:** WhichKey, WhichKeyGroup, WhichKeyDesc, WhichKeySeparator, WhichKeyFloat, WhichKeyBorder
- **illuminate:** IlluminatedWordText, IlluminatedWordRead, IlluminatedWordWrite
- **Lazy:** LazyButton, LazyButtonActive, LazyH1, LazySpecial, LazyProgressDone, LazyProgressTodo
- **Mason:** MasonHeader, MasonHighlight, MasonHighlightBlock, MasonHighlightBlockBold, MasonMuted, MasonError, MasonWarning

## Lualine Theme

Custom table returned from `groups.lua` using mode colors:

| Mode    | Color  |
|---------|--------|
| normal  | purple |
| insert  | green  |
| visual  | pink   |
| replace | red    |
| command | orange |

## Loading

`init.lua` sequence:
1. `vim.o.termguicolors = true`
2. `vim.o.background = "dark"`
3. `vim.cmd("highlight clear")`
4. `vim.g.colors_name = "omtheme"`
5. `groups.setup(require("omtheme.palette"))`

`plugins/init.lua` lazy spec:
```lua
{
  name = "omtheme",
  dir = vim.fn.stdpath("config"),
  lazy = false,
  priority = 1000,
  config = function() require("omtheme") end,
},
```

Lualine `opts.theme` changes from `"tokyonight"` to the table returned by `require("omtheme.groups").lualine_theme(require("omtheme.palette"))`.
