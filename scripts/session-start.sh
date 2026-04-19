#!/bin/bash
set -eu
# Avoid pipefail: internal pipes use head -N which closes early, causing
# SIGPIPE for upstream commands (sort, sed). This is normal and not an error.
# wyx SessionStart hook — report existing wyx artifact coverage

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
PROJECT_DIR="${PROJECT_DIR%/}"

# Common find exclusion patterns (shared across all find calls)
FIND_EXCLUDES=(
  -not -path '*/node_modules/*' -not -path '*/.git/*'
  -not -path '*/dist/*' -not -path '*/build/*'
  -not -path '*/.next/*' -not -path '*/vendor/*'
  -not -path '*/.venv/*' -not -path '*/venv/*'
)

# Warn if jq is missing (drift context hook depends on it)
if ! command -v jq &>/dev/null; then
  echo "wyx: jq not found — drift context (boundary checking) is disabled. Install jq for full protection."
fi

# Find wyx spec files, excluding common build/dependency directories
find_specs() {
  find "$PROJECT_DIR" -name "$1" \
    "${FIND_EXCLUDES[@]}" \
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
  echo "wyx: No specs found. Try /wyx:audit to discover modules that could benefit from specs."
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
  # action defaults to "detect" for backward compat with pre-v0.23 entries
  last_action=$(echo "$last_entry" | jq -r '.action // "detect"' 2>/dev/null)
  if [ "$last_action" = "fix" ]; then
    # Fix entry: report remaining drift and the originating detect's timestamp
    last_drift=$(echo "$last_entry" | jq -r '.specs_remaining // 0' 2>/dev/null)
    ref_ts=$(echo "$last_entry" | jq -r '.ref_ts // empty' 2>/dev/null)
    detect_ts="${ref_ts:-$last_ts}"
  else
    last_drift=$(echo "$last_entry" | jq -r '.specs_with_drift // 0' 2>/dev/null)
    detect_ts="$last_ts"
  fi
  if [ -n "$last_ts" ]; then
    if [ "$last_action" = "fix" ]; then
      if [ "$last_drift" = "0" ]; then
        echo "Last drift check: $detect_ts (all fixed at $last_ts)"
      else
        echo "Last drift check: $detect_ts ($last_drift spec(s) pending after fix at $last_ts)"
      fi
    else
      echo "Last drift check: $last_ts ($last_drift spec(s) with drift — rerun to update)"
    fi
    # Build a single reference file representing the last drift *measurement*.
    # Always use the detect ts (not fix ts): a fix entry is a mid-workflow
    # marker, not a new measurement. Any spec or code change since the last
    # detect warrants a new scan, even if a fix happened in between. The JSONL
    # file mtime would track the fix append time, so we derive the reference
    # from the detect ts instead. Fall back to JSONL file mtime only when
    # touch -d is unavailable (non-GNU coreutils).
    _ts_ref=$(mktemp 2>/dev/null) || _ts_ref="/tmp/wyx-ts-ref-$$"
    if touch -d "$detect_ts" "$_ts_ref" 2>/dev/null; then
      ref_file="$_ts_ref"
    else
      ref_file="$drift_history"
    fi
    # Warn if specs modified since last drift check
    newer_than_drift=$(find "$PROJECT_DIR" \( -name "CONCEPT.md" -o -name "PIPELINE.md" -o -name "SYNCS.md" \) \
      -newer "$ref_file" \
      "${FIND_EXCLUDES[@]}" \
      2>/dev/null | head -1)
    if [ -n "$newer_than_drift" ]; then
      echo "Specs modified since last drift check — consider running /wyx:concept drift"
    fi
    # Report code directories modified since last drift check
    changed_dirs=$(find "$PROJECT_DIR" -type f \
      \( -name "*.ts" -o -name "*.js" -o -name "*.tsx" -o -name "*.jsx" -o -name "*.py" -o -name "*.rs" -o -name "*.go" -o -name "*.java" -o -name "*.svelte" -o -name "*.vue" \) \
      -newer "$ref_file" \
      "${FIND_EXCLUDES[@]}" \
      2>/dev/null | xargs -r dirname 2>/dev/null | sort -u | sed "s|^$PROJECT_DIR/||" | head -5)
    rm -f "$_ts_ref" 2>/dev/null
    if [ -n "$changed_dirs" ]; then
      changed_list=$(echo "$changed_dirs" | tr '\n' ',' | sed 's/,$//')
      echo "Code modified since last drift: $changed_list"
    fi
  fi
fi

# Check ARCHITECTURE.md freshness
if [ -f "$PROJECT_DIR/ARCHITECTURE.md" ]; then
  newer_specs=$(find "$PROJECT_DIR" \( -name "CONCEPT.md" -o -name "PIPELINE.md" -o -name "SYNCS.md" \) \
    -newer "$PROJECT_DIR/ARCHITECTURE.md" \
    "${FIND_EXCLUDES[@]}" \
    2>/dev/null | head -1)
  if [ -n "$newer_specs" ]; then
    echo "Warning: ARCHITECTURE.md may be stale — specs modified since last /wyx:map run."
  fi
fi

# Suggest uncovered modules (directories with >2 source files but no CONCEPT.md, PIPELINE.md, or SYNCS.md)
# Single-pass: find all source files, extract dirs, count per dir, filter — no nested find
if [ "$concept_count" -gt 0 ]; then
  # Collect dirs with specs (for exclusion)
  spec_dirs=""
  for spec_file in $concepts $pipelines $syncs; do
    [ -z "$spec_file" ] && continue
    spec_dirs="$spec_dirs|$(dirname "$spec_file")"
  done
  spec_dirs="${spec_dirs#|}"  # strip leading |

  uncovered=$(find "$PROJECT_DIR" -type f \
    \( -name "*.ts" -o -name "*.js" -o -name "*.tsx" -o -name "*.jsx" \
       -o -name "*.py" -o -name "*.rs" -o -name "*.go" -o -name "*.java" \
       -o -name "*.svelte" -o -name "*.vue" -o -name "*.jl" \) \
    "${FIND_EXCLUDES[@]}" \
    -not -path '*/target/*' -not -path '*/__pycache__/*' \
    -not -name '.*' -not -path '*/.*' \
    2>/dev/null \
    | sed 's|/[^/]*$||' \
    | sort | uniq -c | sort -rn \
    | awk -v threshold=2 '$1 > threshold { print $2 }' \
    | while IFS= read -r d; do
        # Skip dirs that have a spec
        if [ -n "$spec_dirs" ] && echo "$d" | grep -qE "^($spec_dirs)$"; then
          continue
        fi
        rel="${d#"$PROJECT_DIR"/}"
        # Skip well-known non-concept directories
        case "$rel" in
          tests/*|test/*|spec/*|__tests__/*|docs/*|build/*) continue ;;
          */migrations|*/migrations/*|migrations/*) continue ;;
          */components/ui|*/components/ui/*) continue ;;
          */types|types/*|*/e2e|e2e/*|*/cypress|cypress/*) continue ;;
          */fixtures|fixtures/*|*/stubs|stubs/*|*/mocks|mocks/*) continue ;;
        esac
        printf '%s\n' "$rel"
      done \
    | head -10 \
    | tr '\n' ',' | sed 's/,$//')
  if [ -n "$uncovered" ]; then
    echo "Uncovered modules (>2 source files, no CONCEPT/PIPELINE/SYNCS): $uncovered"
  fi
fi

# Detect spec shadowing: PIPELINE.md without co-located CONCEPT.md stops hook traversal,
# hiding ancestor boundary checking. SYNCS.md does not stop traversal so cannot cause shadowing.
if [ "$concept_count" -gt 0 ]; then
  shadows=""
  for spec_list in "$pipelines"; do
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
        # Guard: dirname(".") returns "." — stop when we can't go higher
        [ "$check_dir" = "$PROJECT_DIR" ] && break
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
    echo "Suggestion: Run /wyx:concept drift to check specs and update this status."
  fi
else
  echo "Suggestion: Run /wyx:concept to create your first concept spec."
fi
