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

If an agent or another process changes files while Diffscope is open, Diffscope marks both panes as stale (`stale (R)`). Press `R` to run a safe reload. When your editor buffer has no unsaved edits, the left pane auto-refreshes its code view; `R` still performs a full safe reload of the changed-file list.

Routine operations are intentionally quiet (open/switch/reload/stage). Notifications are reserved for warnings and errors.

The changed-files picker shows review progress, additions/deletions, and stale/reviewed files:

```text
2/5 changed files  1 reviewed
➜●✓ M  lua/foo.lua  +12 -3
    A  README.md    +40 -0
```

Addition counts are highlighted green; deletion counts are highlighted red.

## Default mappings

| Key | Action |
| --- | --- |
| `f` | Open changed-files picker with filter, stats, stale/reviewed markers |
| `/` | Filter inside the changed-files picker |
| `d` | Toggle reviewed marker, also works from the file picker |
| `R` | Reload external changes, also works from the file picker |
| `s` | Write and stage the current file |
| `r` | Reset current file (press twice to confirm) |
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
    reload = "R",
    toggle_reviewed = "d",
    picker_filter = "/",
  },
})
```

## License

MIT
