#!/bin/bash
# wyx post-edit check — PostToolUse hook for Write|Edit|NotebookEdit
# After a file edit near a CONCEPT.md, reinjects the dependency list as a
# focused reminder for boundary compliance. Complements PreToolUse:
#   PreToolUse = full boundary context before edit (guidance)
#   PostToolUse = dependency list after edit (verification prompt)
# Design: no import parsing, language-agnostic, silent when no spec found.

set -euo pipefail

input=$(cat)
# jq is required — if missing, file_path stays empty and we exit below.
# This is intentional: SessionStart hook warns about missing jq (fires once
# per session). NotebookEdit uses notebook_path instead of file_path — try both.
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null) || file_path=""

if [ -z "$file_path" ]; then
  exit 0
fi

# Skip inert files (non-code)
case "$file_path" in
  *.json|*.jsonl|*.lock|*.log|*.txt) exit 0 ;;
esac

# Skip spec file edits — editing the spec itself doesn't need a dependency reminder
case "$file_path" in
  *CONCEPT.md|*PIPELINE.md|*SYNCS.md) exit 0 ;;
esac

# Resolve project directory
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  PROJECT_DIR="${CLAUDE_PROJECT_DIR%/}"
else
  PROJECT_DIR=$(echo "$input" | jq -r '.cwd // empty' 2>/dev/null) || PROJECT_DIR=""
  if [ -z "$PROJECT_DIR" ]; then
    PROJECT_DIR="$(pwd)"
  fi
  PROJECT_DIR="${PROJECT_DIR%/}"
fi

# Guard against PROJECT_DIR="" or "/" — would cause upward traversal to
# scan ancestors of the edited file up to filesystem root (matches
# drift-context.sh).
if [ -z "$PROJECT_DIR" ] || [ "$PROJECT_DIR" = "/" ]; then
  exit 0
fi

# Resolve relative file paths to absolute
case "$file_path" in
  /*) ;;
  *) file_path="$PROJECT_DIR/$file_path" ;;
esac

# Extract a section from a spec file (between ## heading and next ##)
extract_section() {
  local file="$1" section="$2"
  tr -d '\r' < "$file" | sed -n "/^## ${section}[[:space:]]*$/,/^## [^#]/{/^## ${section}[[:space:]]*$/d;/^## [^#]/d;p;}" 2>/dev/null \
    | sed '/^$/d' || true
}

# Walk upward from file's directory to find nearest CONCEPT.md
dir=$(dirname "$file_path")
concept_path=""

while [ "$dir" != "/" ] && [ "$dir" != "." ]; do
  case "$dir/" in
    "$PROJECT_DIR/"*) ;;
    *) break ;;
  esac
  if [ -f "$dir/CONCEPT.md" ]; then
    concept_path="$dir/CONCEPT.md"
    break
  fi
  dir=$(dirname "$dir")
done

if [ -z "$concept_path" ]; then
  exit 0
fi

# Extract dependencies (lowercase priority; capitalized fallback for older specs)
dependencies=$(extract_section "$concept_path" "dependencies")
if [ -z "$dependencies" ]; then
  dependencies=$(extract_section "$concept_path" "Dependencies")
fi

# No dependencies declared — nothing to remind about
if [ -z "$dependencies" ]; then
  exit 0
fi

# Build post-edit reminder with dependency list
relative_spec="${concept_path#"$PROJECT_DIR"/}"
concept_name=$(basename "$(dirname "$concept_path")")

ctx="wyx post-edit check: file governed by ${concept_name} (${relative_spec}).
Declared dependencies:
${dependencies}
Verify any imports added by this edit target only declared dependencies above. Imports from undeclared concepts are boundary violations."

jq -n --arg ctx "$ctx" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'

exit 0
