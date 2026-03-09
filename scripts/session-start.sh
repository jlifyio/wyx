#!/bin/bash
set -euo pipefail
# wyx SessionStart hook — report existing wyx artifact coverage

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
PROJECT_DIR="${PROJECT_DIR%/}"

# Warn if jq is missing (drift context hook depends on it)
if ! command -v jq &>/dev/null; then
  echo "wyx: jq not found — drift context (boundary checking) is disabled. Install jq for full protection."
fi

# Find wyx spec files, excluding common build/dependency directories
find_specs() {
  find "$PROJECT_DIR" -name "$1" \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    -not -path '*/dist/*' -not -path '*/build/*' \
    -not -path '*/.next/*' -not -path '*/vendor/*' \
    -not -path '*/.venv/*' -not -path '*/venv/*' \
    2>/dev/null | sort || true
}

concepts=$(find_specs "CONCEPT.md")
pipelines=$(find_specs "PIPELINE.md")
syncs=$(find_specs "SYNCS.md")

count_lines() {
  if [ -z "$1" ]; then echo 0; else echo "$1" | wc -l | tr -d ' '; fi
}

concept_count=$(count_lines "$concepts")
pipeline_count=$(count_lines "$pipelines")
sync_count=$(count_lines "$syncs")

total=$((concept_count + pipeline_count + sync_count))

# No artifacts found — suggest getting started
if [ "$total" -eq 0 ]; then
  echo "wyx: No specs found. Try /wyx:concept to discover modules that could benefit from concept specs."
  exit 0
fi

# Build report
report="wyx artifacts:"

# Strip PROJECT_DIR prefix using parameter expansion (avoids sed metacharacter issues)
strip_prefix() {
  printf '%s\n' "$1" | while IFS= read -r line; do printf '%s\n' "${line#"$PROJECT_DIR"/}"; done | tr '\n' ',' | sed 's/,$//'
}

if [ "$concept_count" -gt 0 ]; then
  names=$(strip_prefix "$concepts")
  report="$report CONCEPT($concept_count: $names)"
fi

if [ "$pipeline_count" -gt 0 ]; then
  names=$(strip_prefix "$pipelines")
  report="$report PIPELINE($pipeline_count: $names)"
fi

if [ "$sync_count" -gt 0 ]; then
  names=$(strip_prefix "$syncs")
  report="$report SYNCS($sync_count: $names)"
fi

echo "$report"

# Report last drift check date if history exists
drift_history="$PROJECT_DIR/.claude/wyx-drift-history.jsonl"
if [ -f "$drift_history" ] && command -v jq &>/dev/null; then
  last_entry=$(grep -v '^[[:space:]]*$' "$drift_history" | tail -1 || true)
  last_ts=$(echo "$last_entry" | jq -r '.ts // empty' 2>/dev/null)
  last_drift=$(echo "$last_entry" | jq -r '.specs_with_drift // 0' 2>/dev/null)
  if [ -n "$last_ts" ]; then
    echo "Last drift check: $last_ts ($last_drift spec(s) with drift)"
    # Warn if specs modified since last drift check
    newer_than_drift=$(find "$PROJECT_DIR" \( -name "CONCEPT.md" -o -name "PIPELINE.md" -o -name "SYNCS.md" \) \
      -newer "$drift_history" \
      -not -path '*/node_modules/*' -not -path '*/.git/*' \
      -not -path '*/dist/*' -not -path '*/build/*' \
      -not -path '*/.next/*' -not -path '*/vendor/*' \
      -not -path '*/.venv/*' -not -path '*/venv/*' \
      2>/dev/null | head -1)
    if [ -n "$newer_than_drift" ]; then
      echo "Specs modified since last drift check — consider running /wyx:concept drift"
    fi
  fi
fi

# Check ARCHITECTURE.md freshness
if [ -f "$PROJECT_DIR/ARCHITECTURE.md" ]; then
  newer_specs=$(find "$PROJECT_DIR" \( -name "CONCEPT.md" -o -name "PIPELINE.md" -o -name "SYNCS.md" \) \
    -newer "$PROJECT_DIR/ARCHITECTURE.md" \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    -not -path '*/dist/*' -not -path '*/build/*' \
    -not -path '*/.next/*' -not -path '*/vendor/*' \
    -not -path '*/.venv/*' -not -path '*/venv/*' \
    2>/dev/null | head -1)
  if [ -n "$newer_specs" ]; then
    echo "Warning: ARCHITECTURE.md may be stale — specs modified since last /wyx:map run."
  fi
fi

# Suggest uncovered modules (directories with >5 source files but no CONCEPT.md)
if [ "$concept_count" -gt 0 ]; then
  uncovered=""
  while IFS= read -r dir; do
    [ -z "$dir" ] && continue
    rel="${dir#"$PROJECT_DIR"/}"
    # Skip well-known non-concept directories
    case "$rel" in
      tests/*|test/*|spec/*|__tests__/*|docs/*) continue ;;
    esac
    case "$rel" in
      */migrations|*/migrations/*|migrations/*) continue ;;
    esac
    case "$rel" in
      */components/ui|*/components/ui/*) continue ;;
    esac
    uncovered="${uncovered:+$uncovered, }$rel"
  done < <(find "$PROJECT_DIR" -mindepth 1 -type d \
    -not -path '*/node_modules/*' -not -path '*/dist/*' \
    -not -path '*/build/*' -not -path '*/.next/*' \
    -not -path '*/vendor/*' -not -path '*/.venv/*' \
    -not -path '*/venv/*' -not -path '*/target/*' \
    -not -path '*/__pycache__/*' \
    -not -name '.*' -not -path '*/.*' \
    2>/dev/null | while IFS= read -r d; do
      # Skip directories that already have a CONCEPT spec
      if [ -f "$d/CONCEPT.md" ]; then
        continue
      fi
      # Count source files (non-recursive, exclude hidden and common non-source)
      file_count=$(find "$d" -maxdepth 1 -type f \
        -not -name '.*' -not -name '*.lock' -not -name '*.log' \
        2>/dev/null | wc -l | tr -d ' ')
      if [ "$file_count" -gt 2 ]; then
        printf '%s\n' "$d"
      fi
    done | sort)
  if [ -n "$uncovered" ]; then
    echo "Uncovered modules (>2 files, no CONCEPT.md): $uncovered"
  fi
fi

# Detect spec shadowing: non-CONCEPT specs without co-located CONCEPT.md may hide ancestor boundary checking
if [ "$concept_count" -gt 0 ]; then
  shadows=""
  for spec_list in "$pipelines" "$syncs"; do
    [ -z "$spec_list" ] && continue
    while IFS= read -r spec_file; do
      [ -z "$spec_file" ] && continue
      spec_dir=$(dirname "$spec_file")
      # Safe if this directory already has CONCEPT.md
      [ -f "$spec_dir/CONCEPT.md" ] && continue
      # Walk up to check for ancestor CONCEPT.md
      check_dir=$(dirname "$spec_dir")
      while true; do
        case "$check_dir/" in "$PROJECT_DIR/"*) ;; *) break ;; esac
        if [ -f "$check_dir/CONCEPT.md" ]; then
          rel_spec="${spec_file#"$PROJECT_DIR"/}"
          rel_concept="${check_dir#"$PROJECT_DIR"/}/CONCEPT.md"
          shadows="${shadows:+$shadows; }$rel_spec hides $rel_concept"
          break
        fi
        check_dir=$(dirname "$check_dir")
      done
    done <<< "$spec_list"
  done
  if [ -n "$shadows" ]; then
    echo "Warning: Spec shadowing detected — $shadows. Files in these directories won't get boundary checking from the ancestor CONCEPT.md. Fix: add a CONCEPT.md to the shadowing directory, or move the spec."
  fi
fi

# Contextual next-step suggestion based on project state
if [ "$concept_count" -gt 0 ]; then
  # Check if drift was checked recently (within last 7 days)
  suggest_drift=true
  if [ -f "$drift_history" ] && command -v jq &>/dev/null; then
    last_ts=$(grep -v '^[[:space:]]*$' "$drift_history" | tail -1 | jq -r '.ts // empty' 2>/dev/null)
    if [ -n "$last_ts" ]; then
      # Compare dates (YYYY-MM-DD prefix)
      last_date="${last_ts:0:10}"
      today=$(date -u +%Y-%m-%d 2>/dev/null || true)
      if [ "$last_date" = "$today" ]; then
        suggest_drift=false
      fi
    fi
  fi
  if [ "$suggest_drift" = true ]; then
    echo "Suggestion: Run /wyx:concept drift to check if specs are up to date."
  fi
else
  echo "Suggestion: Run /wyx:concept to create your first concept spec."
fi
