# claude-code-statusline

A custom status line script for [Claude Code](https://code.claude.com) with colored repo display, effort level, context progress bar, session cost, and rate limit tracking.

## What it shows

```
lemuelfigueira @ myrepo on feat/auth | Claude Sonnet 4.6 [high]       [======----] 30% | $1.00 | 5h 4%
```

- **Owner @ repo** (purple/blue) or current directory (purple) when outside a git repo
- **Git branch**
- **Model name** with **effort level** (color-coded: green=low, yellow=medium, red=high, magenta=xhigh/max)
- **Context progress bar** right-aligned to terminal width
- **Session cost** in USD
- **5-hour rate limit** usage with reset time
- Automatically drops `resets TIME` → cost → when terminal is too narrow to fit everything

## Requirements

- `bash`
- `jq`
- `git`
- **Claude Code v2.1.153+** — required for full visual fidelity. Older versions may be missing fields such as `effort.level`, `session_name`, `cost`, and `rate_limits` in the status line JSON, and do not inject the `COLUMNS` variable needed for correct right-alignment.

## Installation

1. Clone this repository:
   ```sh
   git clone https://github.com/ilemuelfigueira/claude-code-statusline.git ~/.claude/statusline
   ```

2. Make the script executable:
   ```sh
   chmod +x ~/.claude/statusline/statusline.sh
   ```

3. Add to `~/.claude/settings.json`:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "bash ~/.claude/statusline/statusline.sh"
     }
   }
   ```

4. Reopen Claude Code — the status line will appear at the bottom of the terminal.

## License

MIT
