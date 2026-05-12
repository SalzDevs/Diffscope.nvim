# Diffscope

Diffscope is a Neovim plugin for reviewing code changes while staying in an editable buffer. It is positioned for agentic coding workflows where users need to understand and correct generated changes quickly.

## Language

**Review Surface**:
A focused workspace where users inspect code changes while keeping the current file editable.
_Avoid_: Diff dashboard, Git client

**Code-shaped Diff**:
A read-only representation of changed code that looks like normal code, with removed and added lines highlighted in place.
_Avoid_: Unified diff, raw diff, patch view

**Editable Buffer**:
The real Neovim file buffer where the user edits the current state of the file.
_Avoid_: Preview buffer, generated buffer

**Changed-files Picker**:
A temporary picker for selecting files with changes inside the Review Surface.
_Avoid_: File explorer, sidebar

**Stale Review**:
A review state where files changed externally after Diffscope opened and need safe reload.
_Avoid_: Live reload, project reload

## Relationships

- A **Review Surface** contains one **Code-shaped Diff** and one **Editable Buffer**.
- A **Changed-files Picker** selects which file is shown in the **Review Surface**.
- A **Stale Review** belongs to an open **Review Surface**.

## Example dialogue

> **Dev:** "When an agent changes a file while Diffscope is open, should the editor auto-reload?"
> **Domain expert:** "No. The **Review Surface** becomes a **Stale Review**. The **Code-shaped Diff** may refresh when safe, but the **Editable Buffer** must not discard user edits without consent."

## Flagged ambiguities

- "diff viewer" can mean raw unified diff or **Code-shaped Diff** — resolved: Diffscope's primary view is **Code-shaped Diff**.
- "file explorer" can imply general project navigation — resolved: Diffscope uses a **Changed-files Picker** only for changed files.
