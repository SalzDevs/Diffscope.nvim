# Diffscope.nvim

A focused diff review workspace for Neovim.

Diffscope turns a tab into a clean review surface with a changed-file list, a unified diff preview, and native side-by-side diff mode powered by Neovim's built-in diff engine.

## Status

Early MVP.

## Requirements

- Neovim 0.9+
- Git, for repository diffs

## Installation

Using `lazy.nvim`:

```lua
{
  "SalzDevs/Diffscope.nvim",
  cmd = "DiffScope",
  opts = {},
}
```

## Usage

```vim
:DiffScope
```

Opens the current Git working tree in a dedicated diff workspace.

```vim
:DiffScope staged
```

Reviews staged changes.

```vim
:DiffScope %
```

Reviews the current file.

```vim
:DiffScope file_a.lua file_b.lua
```

Compares two files directly.

## Default mappings

| Key | Action |
| --- | --- |
| `j` / `k` | Move in the file list |
| `<CR>` | Open selected file in side-by-side diff mode |
| `p` | Preview selected file as unified diff |
| `]c` / `[c` | Next / previous diff hunk |
| `s` | Stage selected file |
| `r` | Reset selected file, with confirmation |
| `?` | Toggle help |
| `q` | Close Diffscope |

## Design goals

- One command should open a useful review mode.
- The user's original window layout should be preserved.
- Native Neovim diff should be reused where it is strongest.
- Git actions should be explicit and safe.
- No command-line alias is installed for `:Diff`; use `:DiffScope`.

## Configuration

```lua
require("diffscope").setup({
  layout = {
    file_panel_width = 32,
  },
  view = {
    default = "unified", -- "unified" or "split"
  },
})
```

## License

MIT
