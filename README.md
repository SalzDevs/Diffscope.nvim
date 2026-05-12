# Diffscope.nvim

A read-only diff code view + regular editor layout for Neovim.

Diffscope opens the current change with two code panes: the left pane is a read-only generated view of the file with diff colors, and the right pane is the regular editable Neovim buffer. The left pane looks like code, not raw unified diff output: no `@@` headers, no `+`/`-` prefixes, just code with removed lines inserted in place and highlighted red, and added lines highlighted green.

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

Opens a dedicated Diffscope tab for the changed files in the repository. If the current file has changes, it is selected first; otherwise Diffscope opens the first changed file.

```vim
:DiffScope staged
```

Shows staged changes in the left read-only code view while keeping the worktree file editable on the right.

```vim
:DiffScope %
```

Opens a diff code view for the current file.

```vim
:DiffScope file_a.lua file_b.lua
```

Compares two files directly. The left pane is the read-only diff code view; the right file is editable.

## UI model

```text
┌──────────────────────────────┬──────────────────────────────┐
│ Read-only diff code view     │ Regular Neovim editor        │
│ same code shape as editor    │ current file                 │
│ removed lines: red bg        │ edit/write normally          │
│ added lines: green bg        │                              │
└──────────────────────────────┴──────────────────────────────┘
```

The right pane is not a preview buffer. It is the actual file, so normal edits and `:write` work as expected. The left pane refreshes after writes. Diffscope owns its review tab, so it does not depend on external file explorers.

If an agent or another process changes files while Diffscope is open, Diffscope marks the view as stale and asks you to press `R` to reload safely.

## Default mappings

| Key | Action |
| --- | --- |
| `f` | Open changed-files picker |
| `]f` / `[f` | Next / previous changed file |
| `]c` / `[c` | Next / previous diff hunk |
| `R` | Reload external changes |
| `s` | Write and stage the current file |
| `r` | Reset current file, with confirmation |
| `?` | Toggle help |
| `q` | Close the diff viewer |

## Design goals

- Left pane should feel like a normal read-only code buffer, not raw diff text.
- Right pane remains a normal Neovim editing experience.
- Changed-file navigation should be built into Diffscope, not delegated to a file explorer.
- Use full-line red/green backgrounds for removed/added code.
- Keep the command simple: `:DiffScope`.
- No command-line alias is installed for `:Diff`; use `:DiffScope`.

## Configuration

```lua
require("diffscope").setup({
  layout = {
    base_width = nil, -- nil keeps viewer/editor panes equal
  },
  mappings = {
    files = "f",
    next_file = "]f",
    prev_file = "[f",
    reload = "R",
    next_hunk = "]c",
    prev_hunk = "[c",
  },
})
```

## License

MIT
