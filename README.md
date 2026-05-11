# Diffscope.nvim

A live, editable diff view for Neovim.

Diffscope opens the current change as a two-pane diff: the left pane is the read-only base version, and the right pane is the real file buffer. You edit the new code directly while Neovim's native diff engine highlights additions, removals, and changed lines.

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

Opens a live diff for the current file when possible. If the current buffer is not a Git file, Diffscope falls back to the first changed file in the repository.

```vim
:DiffScope staged
```

Opens the selected staged change against an editable worktree file.

```vim
:DiffScope %
```

Opens a live diff for the current file.

```vim
:DiffScope file_a.lua file_b.lua
```

Compares two files directly. The right file is editable.

## UI model

```text
┌──────────────────────────────┬──────────────────────────────┐
│ Before / read-only           │ Now / edit this file          │
│ red removed/old lines        │ green added/new lines         │
│                              │ cursor starts here            │
└──────────────────────────────┴──────────────────────────────┘
```

The right pane is not a preview buffer. It is the actual file, so normal edits and `:write` work as expected.

## Default mappings

| Key | Action |
| --- | --- |
| `]c` / `[c` | Next / previous diff hunk |
| `s` | Write and stage the current file |
| `r` | Reset current file, with confirmation |
| `?` | Toggle help |
| `q` | Close diff mode and keep editing the file |

## Design goals

- Open directly into the code, not a separate file-list workflow.
- Make the editable side obvious: right pane = real file.
- Use full-line red/green backgrounds for removed/added code.
- Reuse Neovim's native diff engine.
- No command-line alias is installed for `:Diff`; use `:DiffScope`.

## Configuration

```lua
require("diffscope").setup({
  layout = {
    base_width = nil, -- nil keeps both code panes equal
  },
})
```

## License

MIT
