#!/bin/bash
# Rule gate — structural enforcement for the rules in CLAUDE.md that admit it.
# Wired via workflow-kit.config.json `gates.rules`, so `closing` Phase 1 runs it
# on every release. Run it directly during development:
#
#   bash scripts/check-rules.sh
#
# A rule that nothing invokes is dead code: add a new check here in the same
# change that writes the rule into CLAUDE.md.

set -euo pipefail
shopt -s nullglob

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PLUGIN_ROOT"

fail=0

# --- Rule: every Agent dispatch pins the model ------------------------------
#
# CLAUDE.md -> "Agent dispatch: always pin the model". wyx dispatches only the
# built-in `Explore` agent, which has no frontmatter of its own, so an unpinned
# dispatch inherits the session model and spawns N agents on whatever tier the
# user is running. The callee cannot fix this; only the call site can.
#
# Scope note: `docs/archive/**` is excluded — it holds superseded plans that
# describe historical dispatches and must not be retro-fixed.
printf -- '--- agent dispatch model pin ---\n'

# Assert the scan scope before scanning. "No violations" and "the scanner never
# looked" are otherwise the same output — the silent-clean shape this plugin's
# own drift rules exist to prevent.
if [ ! -d skills ]; then
    echo "MISSING SCAN ROOT: skills/ — an eroded scope reports clean."
    exit 1
fi

dispatch_hits=0
unpinned=0
# Iterate files first, then grep -n WITHIN each file. Parsing `grep -rn`'s
# combined `path:line:content` breaks on a path containing a colon: the line
# number comes back as a path fragment and the arithmetic below dies with an
# unbound-variable error pointing at nothing useful. Splitting the loops removes
# the ambiguity rather than trying to parse around it.
while IFS= read -r f; do
    while IFS= read -r n; do
        dispatch_hits=$((dispatch_hits + 1))
        # Search the enclosing markdown SECTION (heading to heading), not a fixed
        # window and not a paragraph. Both narrower scopes false-flagged a
        # genuinely pinned dispatch written in this repo's own discursive style:
        # `subagent_type` on one line, an explanatory paragraph, then `model:`
        # several lines and one blank line further down. A section is the unit a
        # dispatch and its rationale actually occupy here.
        #
        # Bias note: this rule is deliberately tuned AGAINST false positives,
        # which is the opposite of the drift-tier decision in CLAUDE.md. The
        # reason is the failure direction — an unpinned dispatch costs the wrong
        # model tier, while a false positive gets the whole gate switched off.
        # Residual (accepted): a section documenting two dispatches, one pinned
        # and one not, passes on the pinned one.
        lo=$(awk -v n="$n" 'NR<=n && /^#{1,6} / {l=NR} END {print (l ? l : 1)}' "$f")
        hi=$(awk -v n="$n" 'NR>n && /^#{1,6} / {print NR-1; found=1; exit} END {if (!found) print NR}' "$f")
        if ! sed -n "${lo},${hi}p" "$f" | grep -qE "model: *'?(opus|sonnet|haiku)"; then
            printf '  UNPINNED: %s:%s — Agent dispatch with no model: in its paragraph\n' "$f" "$n"
            unpinned=$((unpinned + 1))
        fi
    done < <(grep -n 'subagent_type' "$f" 2>/dev/null | cut -d: -f1 || true)
done < <(find skills -type f -name '*.md' ! -path '*/archive/*' 2>/dev/null | sort)

if [ "$dispatch_hits" -eq 0 ]; then
    # Not a pass. wyx has dispatches; zero hits means the grep or the scope broke.
    echo "  NO DISPATCHES FOUND — the check scanned nothing. Verify the scope."
    fail=$((fail + 1))
elif [ "$unpinned" -gt 0 ]; then
    printf '  %d of %d dispatch(es) unpinned.\n' "$unpinned" "$dispatch_hits"
    printf '  Fix: pass model: on the Agent call. Tier by failure direction —\n'
    printf '       visible-error fan-out (map) = sonnet, absence-claim fan-out (drift) = opus.\n'
    printf '       See CLAUDE.md -> "Agent dispatch: always pin the model".\n'
    fail=$((fail + 1))
else
    printf '  OK: %d dispatch(es), all pinned.\n' "$dispatch_hits"
fi

# --- Shell syntax -----------------------------------------------------------
printf -- '--- shell syntax ---\n'
nscripts=0
nbad=0
for s in scripts/*.sh hooks/*.sh; do
    nscripts=$((nscripts + 1))
    bash -n "$s" || { printf '  SYNTAX FAIL: %s\n' "$s"; nbad=$((nbad + 1)); fail=$((fail + 1)); }
done
if [ "$nbad" -eq 0 ]; then
    printf '  OK: %d shell script(s) parse.\n' "$nscripts"
else
    printf '  %d of %d shell script(s) FAILED to parse.\n' "$nbad" "$nscripts"
fi

if [ "$fail" -gt 0 ]; then
    printf '\n%d rule violation(s) found.\n' "$fail"
    exit 1
fi

printf '\n=== all rule gates passed ===\n'
