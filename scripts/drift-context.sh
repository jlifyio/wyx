#!/bin/bash
# wyx drift context — PreToolUse hook for Write|Edit
# When a file is written near a CONCEPT.md, PIPELINE.md, or SYNCS.md,
# outputs spec context including boundary declarations so the LLM can
# self-check boundary compliance. This replaces aspirational CLAUDE.md
# rules with a mechanical checkpoint.

set -euo pipefail

input=$(cat)
# jq is required — if missing, file_path stays empty and we exit below.
# This is intentional: SessionStart hook warns about missing jq (fires once per session).
# NotebookEdit uses notebook_path instead of file_path — try both.
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null) || file_path=""

if [ -z "$file_path" ]; then
  exit 0
fi

# Skip inert files (but allow .md edits — editing specs should show context)
case "$file_path" in
  *.json|*.jsonl|*.lock|*.log|*.txt) exit 0 ;;
esac

# Resolve project directory — CLAUDE_PROJECT_DIR is set by Claude Code for hooks
# Fall back to cwd from hook input, then to current directory
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  PROJECT_DIR="${CLAUDE_PROJECT_DIR%/}"
else
  PROJECT_DIR=$(echo "$input" | jq -r '.cwd // empty' 2>/dev/null) || PROJECT_DIR=""
  if [ -z "$PROJECT_DIR" ]; then
    PROJECT_DIR="$(pwd)"
  fi
  PROJECT_DIR="${PROJECT_DIR%/}"
fi

# Resolve relative file paths to absolute using PROJECT_DIR
case "$file_path" in
  /*) ;; # already absolute
  *) file_path="$PROJECT_DIR/$file_path" ;;
esac

# Extract a section's content from a wyx spec file (between ## heading and next ##)
extract_section() {
  local file="$1" section="$2"
  tr -d '\r' < "$file" | sed -n "/^## ${section}[[:space:]]*$/,/^## [^#]/{/^## ${section}[[:space:]]*$/d;/^## [^#]/d;p;}" 2>/dev/null \
    | sed '/^$/d' || true
}

# Search upward from file's directory for wyx spec files
dir=$(dirname "$file_path")
found_specs=""
spec_context=""
boundary_context=""

while [ "$dir" != "/" ] && [ "$dir" != "." ]; do
  # Stop searching above the project root (trailing slash prevents sibling match)
  case "$dir/" in
    "$PROJECT_DIR/"*) ;;
    *) break ;;
  esac

  for spec in "$dir"/CONCEPT.md "$dir"/PIPELINE.md "$dir"/SYNCS.md; do
    if [ -f "$spec" ]; then
      relative_spec="${spec#"$PROJECT_DIR"/}"
      found_specs="${found_specs:+$found_specs, }${relative_spec}"

      # Extract purpose (lowercase priority; falls back to capitalized for older specs)
      purpose=$(extract_section "$spec" "purpose")
      if [ -z "$purpose" ]; then
        purpose=$(extract_section "$spec" "Purpose")
      fi
      if [ -n "$purpose" ]; then
        spec_context="${spec_context}  - ${relative_spec}: ${purpose}
"
      else
        spec_context="${spec_context}  - ${relative_spec}
"
      fi

      # Extract boundary declarations from CONCEPT.md and PIPELINE.md files
      case "$spec" in
        *CONCEPT*)
          interactions=$(extract_section "$spec" "interactions")
          if [ -z "$interactions" ]; then
            interactions=$(extract_section "$spec" "Interactions")
          fi
          if [ -n "$interactions" ]; then
            boundary_context="${boundary_context}  [${relative_spec} ## interactions]
${interactions}
"
          fi
          # Extract dependencies (lowercase priority; falls back to capitalized for older specs)
          dependencies=$(extract_section "$spec" "dependencies")
          if [ -z "$dependencies" ]; then
            dependencies=$(extract_section "$spec" "Dependencies")
          fi
          if [ -n "$dependencies" ]; then
            boundary_context="${boundary_context}  [${relative_spec} ## dependencies]
${dependencies}
"
          fi
          if [ -z "$interactions" ] && [ -z "$dependencies" ]; then
            boundary_context="${boundary_context}  [${relative_spec}: no boundary declarations found]
"
          fi
          ;;
        *PIPELINE*)
          # Extract data boundary (access constraints, not quality invariants)
          data_boundary=$(extract_section "$spec" "data boundary")
          if [ -z "$data_boundary" ]; then
            data_boundary=$(extract_section "$spec" "Data boundary")
          fi
          if [ -n "$data_boundary" ]; then
            boundary_context="${boundary_context}  [${relative_spec} ## data boundary]
${data_boundary}
"
          fi
          ;;
      esac
    fi
  done

  # Stop at the first directory with any spec
  if [ -n "$found_specs" ]; then
    break
  fi
  dir=$(dirname "$dir")
done

# DX-1: If specs found but no boundary context (shadowing case — PIPELINE.md or SYNCS.md
# stopped traversal without a co-located CONCEPT.md), look for ancestor CONCEPT.md
# and inject its boundaries with a caveat note
if [ -n "$found_specs" ] && [ -z "$boundary_context" ]; then
  ancestor_dir=$(dirname "$dir")
  while [ "$ancestor_dir" != "/" ] && [ "$ancestor_dir" != "." ]; do
    case "$ancestor_dir/" in
      "$PROJECT_DIR/"*) ;;
      *) break ;;
    esac
    if [ -f "$ancestor_dir/CONCEPT.md" ]; then
      relative_ancestor="${ancestor_dir#"$PROJECT_DIR"/}/CONCEPT.md"
      anc_interactions=$(extract_section "$ancestor_dir/CONCEPT.md" "interactions")
      if [ -z "$anc_interactions" ]; then
        anc_interactions=$(extract_section "$ancestor_dir/CONCEPT.md" "Interactions")
      fi
      anc_dependencies=$(extract_section "$ancestor_dir/CONCEPT.md" "dependencies")
      if [ -z "$anc_dependencies" ]; then
        anc_dependencies=$(extract_section "$ancestor_dir/CONCEPT.md" "Dependencies")
      fi
      if [ -n "$anc_interactions" ] || [ -n "$anc_dependencies" ]; then
        boundary_context="  [SHADOWED — ancestor boundaries from ${relative_ancestor}, may not fully apply to this subdirectory]
"
        if [ -n "$anc_interactions" ]; then
          boundary_context="${boundary_context}  [${relative_ancestor} ## interactions]
${anc_interactions}
"
        fi
        if [ -n "$anc_dependencies" ]; then
          boundary_context="${boundary_context}  [${relative_ancestor} ## dependencies]
${anc_dependencies}
"
        fi
      fi
      break
    fi
    ancestor_dir=$(dirname "$ancestor_dir")
  done
fi

if [ -n "$found_specs" ]; then
  # Build context message
  ctx=$'wyx drift context: specs found near this file.\n'
  ctx="${ctx}${spec_context}"

  # Differentiate message for spec edits vs code edits
  case "$file_path" in
    *CONCEPT.md|*PIPELINE.md|*SYNCS.md)
      if [ -n "$boundary_context" ]; then
        ctx="${ctx}"$'\nDeclared boundaries:\n'"${boundary_context}"$'\n'
      fi
      ctx="${ctx}You are editing a spec file. Ensure changes reflect the current implementation and update boundaries if needed." ;;
    *)
      if [ -n "$boundary_context" ]; then
        ctx="${ctx}"$'\nDeclared boundaries:\n'"${boundary_context}"$'\nVerify this edit does not introduce cross-module imports or data access patterns that violate these declared boundaries.'
      else
        ctx="${ctx}Verify changes align with declared actions, invariants, and operational principles."
      fi ;;
  esac

  # Output as structured JSON with additionalContext (official PreToolUse API)
  # This ensures Claude receives drift context reliably, per hooks reference docs
  jq -n --arg ctx "$ctx" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$ctx}}'
fi

exit 0
