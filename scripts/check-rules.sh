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

# === tripwires ===
# Insertion anchors for workflow-kit `tripwire apply`: every rule block goes
# between this line and the end marker, before the verdict below.

# --- Rule: every Agent dispatch pins the model ------------------------------
#
# CLAUDE.md -> "Agent dispatch: always pin the model": every dispatch passes an
# explicit `model:` naming opus, sonnet or haiku — opus for judgment, sonnet or
# haiku only for read-only lookup. wyx dispatches only the built-in `Explore`
# agent, which has no frontmatter of its own, so an unpinned dispatch inherits
# the session model. The callee cannot fix this; only the call site can.
# Quoting is not part of the rule: 'opus', "opus" and bare opus all pass.
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
#
# Read with `/usr/bin/grep -a` and keep grep's status. Without -a, a NUL or an
# invalid byte on the dispatch line makes grep print "binary file matches"
# instead of the line number, exit 0, and the dispatch silently drops out of
# the count. Exit 1 is "no dispatch in this file"; 2+ means it was not scanned.
skill_files=$(find skills -type f -name '*.md' ! -path '*/archive/*' | sort)
while IFS= read -r f; do
    [ -n "$f" ] || continue
    rc=0
    hits=$(/usr/bin/grep -a -n 'subagent_type' "$f" | cut -d: -f1) || rc=$?
    if [ "$rc" -gt 1 ]; then
        printf '  SCAN ERROR: %s — grep exited %d, so its dispatches were not checked.\n' "$f" "$rc"
        fail=$((fail + 1))
        continue
    fi
    [ -n "$hits" ] || continue
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
        if ! sed -n "${lo},${hi}p" "$f" | /usr/bin/grep -a -qE "model: *['\"]?(opus|sonnet|haiku)"; then
            printf '  UNPINNED: %s:%s — Agent dispatch with no model: naming opus, sonnet or haiku in its section\n' "$f" "$n"
            unpinned=$((unpinned + 1))
        fi
    done <<< "$hits"
done <<< "$skill_files"

if [ "$dispatch_hits" -eq 0 ]; then
    # Not a pass. wyx has dispatches; zero hits means the grep or the scope broke.
    echo "  NO DISPATCHES FOUND — the check scanned nothing. Verify the scope."
    fail=$((fail + 1))
elif [ "$unpinned" -gt 0 ]; then
    printf '  %d of %d dispatch(es) unpinned.\n' "$unpinned" "$dispatch_hits"
    printf '  Fix: pass model: on the Agent call — opus for judgment, sonnet or haiku\n'
    printf '       only for read-only lookup (map = sonnet, drift = opus).\n'
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

# --- Rule: CLAUDE.md does not restate the README's test results --------------
#
# CLAUDE.md -> "Test Results": "Do not restate its numbers here." The README owns
# the figures; a copy in CLAUDE.md goes stale the moment the README is
# re-measured. Matches the result forms the README uses (rates, x/6 and "x of y"
# counts, import/violation counts, N= and p =). Figures that are not in the
# README (3/3 audited projects, 10 concepts) stay allowed. Residual (accepted):
# ratios over another denominator (8/8) and figures reworded into prose
# ("four test gaps") pass.
printf -- '--- CLAUDE.md test results not restated ---\n'
results=$(awk '/^## Test Results[[:space:]]*$/ {on=1; next} /^## / {on=0} on {print "CLAUDE.md:" NR ": " $0}' CLAUDE.md)
if [ -z "$results" ]; then
    echo "  MISSING SCAN ROOT: CLAUDE.md '## Test Results' — an eroded scope reports clean."
    fail=$((fail + 1))
else
    rc=0
    restated=$(printf '%s\n' "$results" | /usr/bin/grep -a -E \
        '[0-9] ?%|[0-9]+ ?/ ?6([^0-9]|$)|[0-9]+ of [0-9]+|[0-9]+ ([A-Za-z-]+ )?(imports?|violations?)|N ?= ?[0-9]|p ?= ?0?\.[0-9]') || rc=$?
    case $rc in
        0)
            printf '  RESTATED: CLAUDE.md "## Test Results" repeats README figures:\n'
            printf '%s\n' "$restated" | sed 's/^/    /'
            printf '  Fix: point to README §Test results and methodology instead.\n'
            fail=$((fail + 1)) ;;
        1)
            printf '  OK: Test Results points to the README without restating figures.\n' ;;
        *)
            printf '  SCAN ERROR: grep exited %d on the Test Results section.\n' "$rc"
            fail=$((fail + 1)) ;;
    esac
fi

# --- Rule: injected hook text is calm, not emphatic -------------------------
#
# CLAUDE.md -> Design Decisions "No qualification, no shouting"; DEC-024 holds
# the rationale. The instructions the per-edit hooks inject around boundary
# declarations carry no capitalised prohibitions.
# Scope: EVERY line of the listed hooks, comments included — a line inside a
# multi-line injected string can start with `#` (a markdown heading), so a
# comment filter would let exactly that text through. Spec content the hooks
# copy verbatim is the user's and is not checked. session-start.sh is out of
# scope: it prints status lines, not instructions.
printf -- '--- injected hook text is calm ---\n'
calm_files="scripts/drift-context.sh scripts/post-check.sh"
calm_hits=0
calm_err=0
for f in $calm_files; do
    if [ ! -f "$f" ]; then
        echo "  MISSING SCAN ROOT: $f — an eroded scope reports clean."
        calm_err=1; continue
    fi
    # Scope guard: a listed hook that no longer emits additionalContext means
    # the injection moved elsewhere, and scanning this file would report clean.
    rc=0
    /usr/bin/grep -a -q 'additionalContext:\$ctx' "$f" || rc=$?
    if [ "$rc" -eq 1 ]; then
        echo "  SCOPE ERROR: $f no longer emits additionalContext — update calm_files."
        calm_err=1; continue
    elif [ "$rc" -gt 1 ]; then
        printf '  SCAN ERROR: %s — grep exited %d.\n' "$f" "$rc"
        calm_err=1; continue
    fi
    # One grep and no pipe, so its own status is the verdict: 1 is clean,
    # 2+ means the file was not scanned (unreadable file, broken pattern).
    # A pipe here would hand the verdict to the last command and hide a 2.
    rc=0
    hits=$(/usr/bin/grep -a -n -E '\b(NEVER|MUST|ALWAYS|CRITICAL|IMPORTANT|BEFORE|NOT)\b' "$f") || rc=$?
    if [ "$rc" -gt 1 ]; then
        printf '  SCAN ERROR: %s — grep exited %d.\n' "$f" "$rc"
        calm_err=1; continue
    fi
    if [ -n "$hits" ]; then
        printf '%s\n' "$hits" | sed "s|^|  EMPHATIC: $f:|"
        calm_hits=1
    fi
done
[ "$calm_err" -eq 0 ] || fail=$((fail + 1))
if [ "$calm_hits" -ne 0 ]; then
    fail=$((fail + 1))
    printf '  Fix: state the rule plainly with its reason (see DEC-024).\n'
fi
if [ "$calm_err" -eq 0 ] && [ "$calm_hits" -eq 0 ]; then
    printf '  OK: injected hook text carries no capitalised prohibitions.\n'
fi

# ─── end tripwires ───

if [ "$fail" -gt 0 ]; then
    printf '\n%d rule violation(s) found.\n' "$fail"
    exit 1
fi

printf '\n=== all rule gates passed ===\n'
