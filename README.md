# Diffscope.nvim

A diff viewer + editor layout for Neovim.

Diffscope opens the current change with a read-only diff viewer on the left and a regular editable Neovim buffer on the right. The left pane shows the actual unified diff with removed lines on a red background and added lines on a green background. The right pane is the current file exactly as you normally edit it.

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

Opens a diff viewer for the current file when possible. If the current buffer is not a Git file, Diffscope falls back to the first changed file in the repository.

```vim
:DiffScope staged
```

Shows the staged diff on the left while keeping the worktree file editable on the right.

```vim
:DiffScope %
```

Opens a diff viewer for the current file.

```vim
:DiffScope file_a.lua file_b.lua
```

Compares two files directly. The left pane shows the diff; the right file is editable.

## UI model

```text
┌──────────────────────────────┬──────────────────────────────┐
│ Diff viewer / read-only      │ Regular Neovim editor        │
│ - removed lines: red bg      │ current file                 │
│ + added lines: green bg      │ edit/write normally          │
└──────────────────────────────┴──────────────────────────────┘
```

The right pane is not a preview buffer. It is the actual file, so normal edits and `:write` work as expected. The diff viewer refreshes after writes. Diff body markers are hidden, so removed/added code is distinguished by background color instead of leading `-`/`+` characters.

## Default mappings

| Key | Action |
| --- | --- |
| `]c` / `[c` | Next / previous diff hunk |
| `s` | Write and stage the current file |
| `r` | Reset current file, with confirmation |
| `?` | Toggle help |
| `q` | Close the diff viewer |

## Design goals

- Left pane is an actual diff, not a second editable buffer.
- Right pane remains a normal Neovim editing experience.
- Use full-line red/green backgrounds for removed/added diff lines.
- Keep the command simple: `:DiffScope`.
- No command-line alias is installed for `:Diff`; use `:DiffScope`.

## Configuration

```lua
require("diffscope").setup({
  layout = {
    base_width = nil, -- nil keeps viewer/editor panes equal
  },
})
```

## License

MIT
