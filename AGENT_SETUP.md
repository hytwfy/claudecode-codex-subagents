# Agent Auto-Setup Guide for Codex Subagents

When a user invokes `/codex-subagents` or `/codex-subagents-en`, the orchestrating agent should ensure the `codex-subagent` MCP server is available **without bothering the user**.

## Detection

Before delegating to Codex subagents, check whether the tool `mcp__codex-subagent__spawn_agents_parallel` is present in your available tools.

If it is **not** present, run the appropriate installer in **automatic/agent mode**.

## Agent Execution Steps

### 1. Detect the operating system

Use the Bash/PowerShell tool to determine the platform.

### 2. Run the installer in auto mode

Choose the correct installer and pass the auto flag.

#### Windows (PowerShell - preferred)

```powershell
cd <repo-path>
.\install.ps1 -Auto
```

#### Windows (CMD fallback)

```cmd
cd <repo-path>
install.bat /auto
```

#### macOS / Linux / WSL

```bash
cd <repo-path>
./install.sh --auto
```

### 3. Read the machine-readable summary

After the installer exits, read:

```text
<repo-path>/.codex-subagents-install-summary.json
```

Example output:

```json
{
  "success": true,
  "os": "windows",
  "mode": "auto",
  "exit_code": 2,
  "dependencies": {
    "python3": true,
    "uvx": true,
    "codex": true
  },
  "actions": {
    "directories_created": true,
    "plugin_installed": true,
    "commands_installed": true,
    "mcp_configured": true
  },
  "requires_user_action": [
    "Run 'codex login' to authenticate"
  ],
  "errors": []
}
```

### 4. Handle exit codes

| Exit Code | Meaning | Agent Action |
|-----------|---------|--------------|
| `0` | Fully configured | Restart Claude Code, then proceed with `/codex-subagents` |
| `1` | Installation failed | Report errors to user and stop; do not retry blindly |
| `2` | Installed, but user action required | Show only the required user actions; wait for user to complete them |

### 5. Required user actions that cannot be automated

The following **must** be done by the user and cannot be performed by the agent:

- **Codex CLI login**: `codex login` (requires browser/OAuth)
- **Installing Python 3** on systems where it is completely missing (unless the OS package manager is available)
- **Restarting Claude Code** to load the newly configured MCP server

When exit code `2` is returned, present the user with a concise checklist, e.g.:

```markdown
I've configured the Codex Subagents plugin. Before we continue, please:

1. Run: `codex login`
2. Completely exit and restart Claude Code
3. Then invoke `/codex-subagents-en <your task>` again
```

## Notes for Agent Implementers

- Do **not** call more than one installer; pick the correct one for the OS.
- The installer is idempotent: running it multiple times is safe.
- In auto mode, the installer will attempt to install `uv` and `codex` automatically, but will never prompt the user.
- If the MCP tool still does not appear after restart, the user may need to verify their Codex CLI login or MCP server configuration manually.

## Example Agent Logic

```text
1. Is mcp__codex-subagent__spawn_agents_parallel available?
   ├─ Yes → proceed with task orchestration
   └─ No → continue to step 2

2. Detect OS
   ├─ Windows → run install.ps1 -Auto
   ├─ macOS/Linux → run ./install.sh --auto
   └─ Unknown → ask user to run installer manually

3. Read .codex-subagents-install-summary.json

4. Based on exit_code:
   ├─ 0 → tell user to restart Claude Code, then continue
   ├─ 1 → report errors and stop
   └─ 2 → show required user actions and stop
```
