# Tmux Skill

Use this skill when working with tmux sessions and terminal multiplexing.

## Commands

### Session Management
- `tmux list-sessions` - List all sessions (always check this first!)
- `tmux new-session -d -s <name>` - Create new detached session
- `tmux new-session -s <name>` - Create new attached session
- `tmux kill-session -t <name>` - Kill session
- `tmux ls` - List sessions (alias)
- `tmux attach -t <name>` - Attach to session

### Window Management (Preferred over split panes)
- `tmux new-window -t <session> -n <name>` - Create new window (then send-keys to run command)
- `tmux kill-window -t <session>:<window>` - Kill window
- `tmux rename-window -t <session>:<window> <name>` - Rename window
- `tmux select-window -t <session>:<window>` - Select window

### Viewing Output (IMPORTANT!)
- `tmux capture-pane -t <session>:<window> -p` - Capture pane output (ALWAYS check this to see what's happening!)
- `tmux send-keys -t <session>:<window> '<command>' C-m` - Send command and press Enter

### Sending Keys
- `tmux send-keys -t <session>:<window> C-c` - Send Ctrl+C to interrupt
- `tmux send-keys -t <session>:<window> '<command>' C-m` - Run command

## Best Practices

1. **ALWAYS check `tmux list-sessions` first** before creating anything
2. **Prefer windows over split panes** - Windows are cleaner
3. Use descriptive session names (e.g., "dreamcraft")
4. Use descriptive window names (e.g., "trunk", "server")
5. Use `capture-pane -p` to check output - don't assume it's running!
6. **When troubleshooting**: Check the output with capture-pane BEFORE searching docs

## Troubleshooting Flow (Max 3 attempts before docs)

1. Check if session exists: `tmux list-sessions`
2. Check window exists: `tmux list-windows -t <session>`
3. Check output: `tmux capture-pane -t <session>:<window> -p`
4. If stuck, send Ctrl+C and restart: `tmux send-keys -t <session>:<window> C-c`

## Examples

```bash
# Check what's running first
tmux list-sessions
tmux list-windows -t dreamcraft

# Create new window and start server
tmux new-window -t dreamcraft -n trunk
tmux send-keys -t dreamcraft:trunk '/home/wilsonn/.asdf/installs/rust/stable/bin/trunk serve' C-m

# Check server output (ALWAYS do this!)
tmux capture-pane -t dreamcraft:trunk -p

# Restart if stuck
tmux send-keys -t dreamcraft:trunk C-c
tmux send-keys -t dreamcraft:trunk '/home/wilsonn/.asdf/installs/rust/stable/bin/trunk serve' C-m
```