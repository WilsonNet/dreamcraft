---
name: herdr
description: Control Herdr, a terminal workspace manager for coding agents, panes, tabs, and long-running background processes such as DreamCraft's stable game session (`:7777`). Use when checking, starting, or restarting background sessions, inspecting sibling panes, or running commands inside Herdr (`HERDR_ENV=1`).
---

# Herdr Skill

Herdr organizes terminals into **workspaces**, **tabs**, and **panes**, recognizes coding agents running inside panes, and exposes the session over the `herdr` CLI (`HERDR_ENV=1`).

Before issuing any Herdr control command, verify you are inside a Herdr-managed pane:

```bash
test "${HERDR_ENV:-}" = 1
```

If this check fails, do not try to inspect or control external Herdr sessions from outside.

---

## DreamCraft Usage

- **Stable game lane (`:7777`)** runs in a dedicated Herdr tab/pane labeled `game` inside `HERDR_WORKSPACE_ID` (`./restart-build.sh`).
- **Keep user focus undisturbed**: always pass `--no-focus` when creating tabs/panes or sending commands to background runners.
- **Inspecting & restarting manually**:

```bash
# Discover tabs & panes in the current workspace
herdr tab list --workspace "$HERDR_WORKSPACE_ID"
herdr pane list --workspace "$HERDR_WORKSPACE_ID"

# Check running foreground process in a pane (note: takes --pane)
herdr pane process-info --pane <pane_id>

# Read recent unwrapped output from a pane
herdr pane read <pane_id> --source recent-unwrapped --lines 60

# Interrupt and launch cleanly in a shell pane
herdr pane send-keys <pane_id> ctrl+c
herdr pane run <pane_id> "./bin/dreamcraft --control=7777"
```

---

## Core CLI Reference

The installed binary is the source of truth:

```bash
herdr --help
herdr pane      # pane list/current/get/layout/process-info/split/rename/read/run/send-keys/wait-output/close
herdr tab       # tab list/create/get/focus/rename/close
herdr workspace # workspace list/create/get/rename/close
herdr agent     # agent list/start/prompt/wait/get/read/send-keys
```

Note: **Never** run bare `herdr` (it launches/attaches the TUI), and never probe mutating subcommands (`herdr workspace create`, etc.) without intending to execute them. Most commands emit JSON.

### IDs & Caller Context

- Workspace ID: `w1`, Tab ID: `w1:t1`, Pane ID: `w1:p1` (never reuse closed IDs).
- Caller context environment variables injected by Herdr:

```bash
printf '%s\n' "$HERDR_WORKSPACE_ID" "$HERDR_TAB_ID" "$HERDR_PANE_ID"
```

- Creation responses return IDs to use next:
  - `herdr workspace create` -> `.result.workspace`, `.result.tab`, `.result.root_pane`
  - `herdr tab create` -> `.result.tab`, `.result.root_pane`
  - `herdr pane split` -> `.result.pane`
- Prefer `--current` when targeting the calling pane; avoid relying on whichever pane currently has UI focus.

---

## Running Background Commands & Waiting

- Create a sibling pane (matching aspect ratio; keep focus on caller and keep `$PWD`):

```bash
herdr pane layout --pane "$HERDR_PANE_ID"
herdr pane split --current --direction right --cwd "$PWD" --no-focus
```

- Run a command in a known shell pane (`pane run` submits text + Enter) and wait on output:

```bash
herdr pane run <pane_id> "cd odin && ./bin/dreamcraft --control=7777"
herdr pane wait-output <pane_id> --match "Control API:" --timeout 10000
herdr pane read <pane_id> --source recent-unwrapped --lines 80
```

- Read sources:
  - `visible` — current viewport
  - `recent` — recent rendered lines with soft wraps
  - `recent-unwrapped` — recent output with soft wraps joined (best for logs)

---

## Coordinating Companion Agents

- An `agent start` requires an idle shell pane (`process-info` shows only the shell):

```bash
herdr agent start reviewer --kind codex --pane <pane_id>
herdr agent prompt reviewer "Review recent changes." --wait --timeout 120000
herdr agent read reviewer --source recent-unwrapped --lines 120
```

- Send logical keys when needed: `herdr agent send-keys reviewer ctrl+c` or `esc`.
- Do **not** guess states from UI badges alone; check `herdr agent get <name>` and `herdr agent read`.

---

## Safety Rules

- Always pass `--no-focus` for background automation unless asked to switch focus.
- Never close workspaces, tabs, panes, or sessions you did not create unless explicitly requested.
- Never run `herdr server stop` from an active session or kill the main Herdr process.
- Full upstream reference is always available via `herdr --skill`.
