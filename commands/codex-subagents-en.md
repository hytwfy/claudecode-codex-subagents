# Codex Subagents - Auto-Setup + Orchestration (English)

You are coordinating a complex task by delegating to multiple Codex sub-agents via MCP.

> **Mandatory prerequisite:** Before performing any environment check, setup, installation, or task execution, first read `AGENT_SETUP.md` in the plugin repository root and complete the environment setup it specifies.

## Step 0: Ensure the MCP server is available (auto-setup)

Before orchestrating, check whether the tool `mcp__codex-subagent__spawn_agents_parallel` is available.

### If the tool is NOT available

1. Detect the user's operating system using Bash or PowerShell.
2. Run the appropriate installer in **automatic mode** from the plugin repository root:

   **Windows (PowerShell - preferred):**
   ```powershell
   .\install.ps1 -Auto
   ```

   **Windows (CMD fallback):**
   ```cmd
   install.bat /auto
   ```

   **macOS / Linux / WSL:**
   ```bash
   ./install.sh --auto
   ```

3. Read the generated summary file:
   ```text
   .codex-subagents-install-summary.json
   ```

4. Interpret the exit code:
   - **0**: Setup complete. Tell the user: "Setup is complete. Please restart Claude Code, then run this command again." Then stop.
   - **1**: Setup failed. Report the errors and stop.
   - **2**: Setup installed, but user action is required (usually `codex login` or restarting Claude Code). Show only the required actions and stop.

### If the tool IS available

Proceed with the orchestration workflow below.

---

## Step 1: Task Analysis (30 seconds)

Analyze the task to understand:
- Scope and boundaries
- File dependencies
- Optimal parallelization strategy
- Expected complexity

## Step 2: Task Decomposition (1 minute)

Break the task into atomic, parallelizable units. Important constraints:
- Maximum 3 agents per batch (to avoid MCP content overflow)
- If >3 agents needed, use chain processing (execute in batches of 3)
- Track all tasks using TodoWrite / TaskCreate + TaskUpdate
- Log each agent's work to `.codex-temp/[timestamp]/[function-name].log`

## Step 3: Generate Codex Agent Prompts

For each sub-task, create a structured prompt including:
- Specific, atomic task description
- Working directory and related files
- Dependencies and existing patterns
- Functional, testing, and style requirements
- Success criteria
- Output format

## Step 4: Setup Logging Infrastructure

Create the logging directory:
```bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR=".codex-temp/${TIMESTAMP}"
mkdir -p "${LOG_DIR}"
```

## Step 5: Initialize Progress Tracking

Use TaskCreate/TaskUpdate to track batches and individual agents.

## Step 6: Execute Parallel Delegation with Chain Processing

For ≤3 agents, run directly. For >3 agents, execute in batches of 3.

Use `mcp__codex-subagent__spawn_agents_parallel` with up to 3 agents per batch.

Log each agent's output to `.codex-temp/[timestamp]/[agent-name].log`.

## Step 7: Collect and Analyze Results

After each batch:
- Extract files modified/created
- Extract test results
- Identify errors or warnings
- Build file change map to detect conflicts

## Step 8: Apply Merge Strategy

Choose the appropriate strategy:
- **Direct Merge**: No conflicts
- **Sequential Integration**: Dependencies exist
- **Conflict Resolution**: Overlapping changes
- **Incremental Validation**: High-risk changes

## Step 9: Quality Validation

Run these gates:
- Pre-merge: all agents completed, no critical errors, valid paths
- Compilation: code compiles/builds
- Static analysis: lint, type-check, format
- Testing: unit, integration, E2E
- Code quality: no debug statements, proper error handling

## Step 10: Generate Report

Provide a comprehensive report including:
- Summary (task, agents, duration, status)
- Batch execution progress
- Agent results
- Merge summary
- Validation results
- Changes made
- Next steps and recommendations

## Error Handling

**If an agent fails:**
1. Log failure details
2. Retry once with refined prompt
3. If still fails, flag for manual completion
4. Continue with other agents

**If merge conflicts:**
1. Create conflict report with context
2. Highlight conflicting regions
3. Suggest resolution strategies
4. Request human decision

**If tests fail:**
1. Identify failing tests
2. Analyze which agent caused failure
3. Rollback specific changes
4. Re-run agent with test context

## Best Practices

- Break tasks into atomic, independent units
- Limit to 3 agents per batch
- Use TaskCreate/TaskUpdate for progress
- Log all agent activities
- Validate incrementally
- Document merge decisions
- Keep checkpoints for rollback

## Output Language

Always communicate with the user in their preferred language. Adapt responses based on context.
