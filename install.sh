#!/usr/bin/env bash

# Codex Subagents Plugin - Cross-platform Installer (Bash)
# Supports: macOS, Linux, WSL
# Modes: interactive (default), --auto / CI=true (agent mode)

set -euo pipefail

# ── Mode detection ──
AUTO_MODE=false
if [[ "${1:-}" == "--auto" ]] || [[ "${CI:-false}" == "true" ]]; then
    AUTO_MODE=true
fi

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Paths ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
PLUGINS_DIR="${CLAUDE_DIR}/plugins"
COMMANDS_DIR="${CLAUDE_DIR}/commands"
MCP_JSON="${SCRIPT_DIR}/.mcp.json"
SUMMARY_FILE="${SCRIPT_DIR}/.codex-subagents-install-summary.json"

# ── Result tracking ──
RESULT_SUCCESS=true
RESULT_OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
RESULT_MODE="interactive"
[[ "$AUTO_MODE" == true ]] && RESULT_MODE="auto"
DEP_PYTHON3=false
DEP_UVX=false
DEP_CODEX=false
ACT_DIRS=false
ACT_PLUGIN=false
ACT_COMMANDS=false
ACT_MCP=false
USER_ACTIONS=()
ERRORS=()

# ── Helpers ──
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Codex Subagents Plugin Installer (Bash)${NC}"
    if [[ "$AUTO_MODE" == true ]]; then
        echo -e "${BLUE}  Mode: automatic (agent)${NC}"
    fi
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

read_yes_no() {
    local prompt="$1"
    [[ "$AUTO_MODE" == true ]] && return 0
    local response
    while true; do
        read -rp "${prompt} (y/n): " response
        case "$response" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

add_user_action() {
    local action="$1"
    if [[ ! " ${USER_ACTIONS[*]} " =~ " ${action} " ]]; then
        USER_ACTIONS+=("$action")
    fi
}

add_error() {
    local msg="$1"
    RESULT_SUCCESS=false
    ERRORS+=("$msg")
    print_error "$msg"
}

# ── JSON summary writer (no jq required) ──
write_summary() {
    local exit_code="$1"
    local actions_json="\"directories_created\": $([[ "$ACT_DIRS" == true ]] && echo true || echo false)"
    actions_json+=", \"plugin_installed\": $([[ "$ACT_PLUGIN" == true ]] && echo true || echo false)"
    actions_json+=", \"commands_installed\": $([[ "$ACT_COMMANDS" == true ]] && echo true || echo false)"
    actions_json+=", \"mcp_configured\": $([[ "$ACT_MCP" == true ]] && echo true || echo false)"

    local user_actions_json="[]"
    if [[ ${#USER_ACTIONS[@]} -gt 0 ]]; then
        user_actions_json="["
        local first=true
        for action in "${USER_ACTIONS[@]}"; do
            [[ "$first" == true ]] || user_actions_json+=", "
            first=false
            user_actions_json+="\"$(echo "$action" | sed 's/\\/\\\\/g; s/"/\\"/g')\""
        done
        user_actions_json+="]"
    fi

    local errors_json="[]"
    if [[ ${#ERRORS[@]} -gt 0 ]]; then
        errors_json="["
        local first=true
        for err in "${ERRORS[@]}"; do
            [[ "$first" == true ]] || errors_json+=", "
            first=false
            errors_json+="\"$(echo "$err" | sed 's/\\/\\\\/g; s/"/\\"/g')\""
        done
        errors_json+="]"
    fi

    cat > "$SUMMARY_FILE" <<EOF
{
  "success": $([[ "$RESULT_SUCCESS" == true ]] && echo true || echo false),
  "os": "$RESULT_OS",
  "mode": "$RESULT_MODE",
  "exit_code": $exit_code,
  "dependencies": {
    "python3": $([[ "$DEP_PYTHON3" == true ]] && echo true || echo false),
    "uvx": $([[ "$DEP_UVX" == true ]] && echo true || echo false),
    "codex": $([[ "$DEP_CODEX" == true ]] && echo true || echo false)
  },
  "actions": {
    $actions_json
  },
  "requires_user_action": $user_actions_json,
  "errors": $errors_json
}
EOF
}

# ── Header ──
print_header

# ── 1. Dependency checks ──
echo -e "${YELLOW}[1/5] Checking dependencies...${NC}"

if command_exists python3; then
    DEP_PYTHON3=true
    print_success "python3: $(python3 --version 2>&1 | head -1)"
elif command_exists python; then
    print_warning "python3 not found, but python is available"
    print_info "Consider creating a python3 symlink or alias"
else
    add_error "python3 is not installed"
fi

if command_exists uvx; then
    DEP_UVX=true
    print_success "uvx: $(uvx --version 2>&1 | head -1)"
else
    add_error "uvx is not installed"
fi

if command_exists codex; then
    DEP_CODEX=true
    print_success "codex: $(codex --version 2>&1 | head -1)"
else
    add_error "codex CLI is not installed"
fi

echo ""

# ── 2. Install missing dependencies ──
if [[ "$DEP_PYTHON3" == false || "$DEP_UVX" == false || "$DEP_CODEX" == false ]]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  Missing dependencies${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if [[ "$DEP_PYTHON3" == false ]]; then
        print_warning "Python 3"
        echo "   Install via your package manager, e.g.:"
        echo "   brew install python3"
        echo "   apt install python3"
        add_user_action "Install Python 3 (e.g., brew install python3 or apt install python3)"
    fi

    if [[ "$DEP_UVX" == false ]]; then
        if read_yes_no "Install uv now?"; then
            echo ""
            echo -e "${YELLOW}[uv] Installing...${NC}"
            if curl -LsSf https://astral.sh/uv/install.sh | sh; then
                export PATH="$HOME/.local/bin:$PATH"
                if command_exists uvx; then
                    DEP_UVX=true
                    print_success "uv installed: $(uvx --version 2>&1 | head -1)"
                else
                    add_error "uv installed but uvx not in PATH; restart terminal and re-run"
                    add_user_action "Restart terminal to load uvx in PATH"
                fi
            else
                add_error "uv installation failed"
                add_user_action "Install uv manually: curl -LsSf https://astral.sh/uv/install.sh | sh"
            fi
        else
            add_user_action "Install uv manually: curl -LsSf https://astral.sh/uv/install.sh | sh"
        fi
        echo ""
    fi

    if [[ "$DEP_CODEX" == false ]]; then
        if read_yes_no "Install Codex CLI now?"; then
            if command_exists npm; then
                echo ""
                echo -e "${YELLOW}[Codex CLI] Installing...${NC}"
                if npm install -g @openai/codex@latest; then
                    if command_exists codex; then
                        DEP_CODEX=true
                        print_success "Codex CLI installed: $(codex --version 2>&1 | head -1)"
                        add_user_action "Run 'codex login' to authenticate"
                    else
                        add_error "Codex CLI installed but not in PATH"
                        add_user_action "Restart terminal, then run: codex login"
                    fi
                else
                    add_error "Codex CLI installation failed"
                    add_user_action "Install Codex CLI manually: npm install -g @openai/codex@latest; then run: codex login"
                fi
            else
                add_error "npm not found; cannot install Codex CLI automatically"
                add_user_action "Install Node.js (https://nodejs.org), then: npm install -g @openai/codex@latest; codex login"
            fi
        else
            add_user_action "Install Codex CLI: npm install -g @openai/codex@latest; then run: codex login"
        fi
        echo ""
    fi
else
    print_success "All dependencies are installed"
    echo ""
fi

# ── 3. Create directories ──
echo -e "${YELLOW}[2/5] Creating directories...${NC}"
if mkdir -p "$PLUGINS_DIR" "$COMMANDS_DIR"; then
    ACT_DIRS=true
    print_success "Directories created"
else
    add_error "Failed to create directories"
fi
echo ""

# ── 4. Install plugin ──
echo -e "${YELLOW}[3/5] Installing plugin...${NC}"

if [ -L "$PLUGINS_DIR/codex-subagents" ]; then
    print_warning "Existing plugin symlink found, removing..."
    rm -f "$PLUGINS_DIR/codex-subagents"
fi

if [ -e "$PLUGINS_DIR/codex-subagents" ]; then
    print_warning "Existing plugin directory found, backing up..."
    mv "$PLUGINS_DIR/codex-subagents" "$PLUGINS_DIR/codex-subagents.bak.$(date +%Y%m%d%H%M%S)"
fi

if ln -s "$SCRIPT_DIR" "$PLUGINS_DIR/codex-subagents" 2>/dev/null; then
    ACT_PLUGIN=true
    print_success "Plugin linked to: $PLUGINS_DIR/codex-subagents"
else
    print_warning "Symlink failed, copying files instead..."
    if cp -R "$SCRIPT_DIR" "$PLUGINS_DIR/codex-subagents"; then
        ACT_PLUGIN=true
        print_success "Plugin copied to: $PLUGINS_DIR/codex-subagents"
    else
        add_error "Failed to install plugin"
    fi
fi

if [[ "$ACT_PLUGIN" == true ]]; then
    if [ -f "$SCRIPT_DIR/commands/codex-subagents.md" ]; then
        cp "$SCRIPT_DIR/commands/codex-subagents.md" "$COMMANDS_DIR/" && print_success "Installed: codex-subagents.md"
    fi
    if [ -f "$SCRIPT_DIR/commands/codex-subagents-en.md" ]; then
        cp "$SCRIPT_DIR/commands/codex-subagents-en.md" "$COMMANDS_DIR/" && print_success "Installed: codex-subagents-en.md"
    fi
    ACT_COMMANDS=true
fi
echo ""

# ── 5. Configure MCP server ──
echo -e "${YELLOW}[4/5] Configuring MCP server...${NC}"

MCP_SERVER_ARGS='"--with", "fastmcp", "codex-as-mcp@latest"'
MCP_JSON_CONFIG='{
  "mcpServers": {
    "codex-subagent": {
      "command": "uvx",
      "args": [--ARGS--]
    }
  }
}'
MCP_JSON_CONFIG="${MCP_JSON_CONFIG/--ARGS--/$MCP_SERVER_ARGS}"

registered=false
if command_exists claude; then
    claude mcp remove codex-subagent -s local >/dev/null 2>&1 || true
    claude mcp remove codex-subagent -s project >/dev/null 2>&1 || true
    claude mcp remove codex-subagent -s user >/dev/null 2>&1 || true
    if claude mcp add --scope user codex-subagent -- uvx --with fastmcp codex-as-mcp@latest >/dev/null 2>&1; then
        registered=true
        ACT_MCP=true
        print_success "MCP server registered with Claude Code"
        if [ -f "$MCP_JSON" ]; then
            rm -f "$MCP_JSON"
            print_info "Removed project-scoped .mcp.json to avoid duplicate server name"
        fi
    else
        print_warning "claude mcp add failed; will use .mcp.json fallback"
    fi
else
    print_warning "claude CLI not found in PATH; will use .mcp.json fallback"
fi

if [[ "$registered" == false ]]; then
    if echo "$MCP_JSON_CONFIG" > "$MCP_JSON"; then
        ACT_MCP=true
        print_success "Plugin .mcp.json written to: $MCP_JSON"
    else
        add_error "Failed to write .mcp.json"
    fi
    print_info "Please restart Claude Code and approve the 'codex-subagent' MCP server from .mcp.json"
fi
echo ""

# ── 6. Verification ──
echo -e "${YELLOW}[5/5] Verifying installation...${NC}"

if [ -f "$PLUGINS_DIR/codex-subagents/.claude-plugin/plugin.json" ]; then
    print_success "Plugin structure is correct"
else
    add_error "Plugin structure is incorrect"
fi

if [ -f "$MCP_JSON" ] && grep -q "codex-subagent" "$MCP_JSON"; then
    print_success "MCP server is configured in .mcp.json"
elif [[ "$registered" == true ]]; then
    print_success "MCP server is configured via Claude Code user config"
else
    add_error "MCP configuration is missing in .mcp.json"
fi

if [[ "$registered" == true ]]; then
    print_success "MCP server registered with Claude Code (active after restart)"
fi

echo ""

# ── Final report ──
if [[ "$RESULT_SUCCESS" == true && "$ACT_MCP" == true && ${#USER_ACTIONS[@]} -eq 0 ]]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Installation complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
else
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  Installation finished with notes${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
fi

echo ""
echo -e "${CYAN}📦 Installation locations:${NC}"
echo "   Plugin:   $PLUGINS_DIR/codex-subagents"
echo "   Commands: $COMMANDS_DIR"
echo "   MCP:      $MCP_JSON"
echo ""

if [[ ${#USER_ACTIONS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  Required user actions:${NC}"
    for action in "${USER_ACTIONS[@]}"; do
        echo "   - $action"
    done
    echo ""
fi

echo -e "${CYAN}🚀 Usage:${NC}"
echo -e "   /codex-subagents <task>     # Chinese"
echo -e "   /codex-subagents-en <task>  # English"
echo ""
echo -e "${CYAN}⚠️  Important:${NC}"
echo "   1. Restart Claude Code completely to load the plugin and MCP server."
echo "   2. Verify with: /mcp"
echo ""

# ── Exit codes ──
# 0 = fully successful
# 1 = installation failed
# 2 = installed but user action required
EXIT_CODE=0
if [[ "$RESULT_SUCCESS" == false ]]; then
    EXIT_CODE=1
elif [[ ${#USER_ACTIONS[@]} -gt 0 ]]; then
    EXIT_CODE=2
fi

write_summary "$EXIT_CODE"

if [[ "$AUTO_MODE" == true ]]; then
    print_info "Agent summary written to: $SUMMARY_FILE"
fi

exit "$EXIT_CODE"
