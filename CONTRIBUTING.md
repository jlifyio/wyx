# Contributing to wyx

We welcome contributions. Here's how to help.

## Bug Reports

Open a GitHub Issue with:
- Title describing the problem
- Reproduction steps (minimal example)
- Expected vs actual behavior
- wyx version and project type (TypeScript, Python, etc.)

## Feature Requests

Open a GitHub Issue with:
- Description of what you need
- Use case and why it matters
- Example of how you'd use it

## Testing the Plugin

wyx has no build step or test suite. Testing is done against real projects.

**Test a single skill:**
```bash
unset CLAUDECODE
cd /path/to/project && claude --plugin-dir /path/to/wyx -p "/wyx:concept"
```

**Test SessionStart hook:**
```bash
CLAUDE_PROJECT_DIR=/path/to/project bash scripts/session-start.sh
```

**Test PreToolUse hook (drift context):**
```bash
echo '{"tool_name":"Write","tool_input":{"file_path":"/path/to/project/src/module/service.ts","content":"code"}}' \
  | CLAUDE_PROJECT_DIR=/path/to/project bash scripts/drift-context.sh
```

## Pull Requests

1. Fork the repository
2. Create a branch: `git checkout -b feature/your-feature-name`
3. Make changes (edit SKILL.md files, scripts, or hooks)
4. Test against a real project (see above)
5. Commit with clear messages (follow CLAUDE.md commit order)
6. Push and submit a PR

**What to test:**
- SessionStart hook fires on new session and reports artifacts correctly
- PreToolUse hook injects boundaries when editing near specs
- Skills generate valid output (run `/wyx:concept`, `/wyx:map`, `/wyx:pipeline`, `/wyx:sync`)
- Shell scripts handle relative paths, CRLF line endings, and missing jq gracefully

Keep changes minimal and focused. One feature or fix per PR.

## Shell Script Conventions

See [CLAUDE.md](CLAUDE.md#shell-script-conventions) for detailed patterns (trailing slash stripping, CRLF handling, case-insensitive extraction). These patterns are critical for correctness.

## Project Notes

- The plugin marketplace is hosted separately at [jlifyio/claude-plugins](https://github.com/jlifyio/claude-plugins)
- Version is managed in `.claude-plugin/plugin.json` only
- PreToolUse hook outputs structured JSON (`hookSpecificOutput.additionalContext`) — verify this format when testing hook changes
