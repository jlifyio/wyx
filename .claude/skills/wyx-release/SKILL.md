---
name: wyx-release
description: Release a new version of wyx — bumps version across all files, commits, tags, pushes, and creates a GitHub release
argument-hint: "<version> (e.g., 0.18.0)"
disable-model-invocation: true
---

# wyx release

Release a new version of wyx.

**Version argument:** $ARGUMENTS

## Pre-flight checks

1. Verify you are on the `main` branch with a clean working tree (`git status`)
2. If no version argument is given:
   - Read the current version from `.claude-plugin/plugin.json`
   - Find the latest git tag (`git describe --tags --abbrev=0`)
   - Show `git log --oneline <latest-tag>..HEAD` so the user can see what changed
   - Based on the commits, suggest which semver bump fits (patch for fixes/chores, minor for features, major for breaking changes) with a short rationale
   - Present all three options (e.g., for `0.18.3`: patch `0.18.4`, minor `0.19.0`, major `1.0.0`) with your recommendation marked, and ask the user to pick one or specify a custom version
3. Validate the version follows semver (e.g., `0.18.0`)

## Release steps

Execute in order. Stop and report if any step fails.

### 1. Update version references

Read each file first, then update the version string in ALL of these:

| File | What to update |
|------|---------------|
| `.claude-plugin/plugin.json` | `"version": "X.Y.Z"` (source of truth) |
| `README.md` | Badge: `version-X.Y.Z-blue` and release tag URL: `releases/tag/vX.Y.Z` |
| `CLAUDE.md` | Any version references in project overview or status sections (if present) |
| MEMORY.md (`/home/junpei/.claude/projects/-mnt-d-Jobs-wyx/memory/MEMORY.md`) | `## Project Status` version (e.g., `v0.17.2+` → `vX.Y.Z+`) |

Also grep the repo for the OLD version number and update any other version references found (skip changelogs, history, and git log output).

### 2. Commit

Commit all version-bumped files with message `vX.Y.Z`. Follow commit conventions (Co-Authored-By trailer). Only include files that were actually changed.

### 3. Tag

```bash
git tag -a vX.Y.Z -m "vX.Y.Z"
```

### 4. Push

```bash
git push origin main
git push origin vX.Y.Z
```

### 5. GitHub Release

```bash
gh release create vX.Y.Z --title "vX.Y.Z" --generate-notes
```

### 6. Verify

Confirm and report:
- `git log --oneline -1` shows the version commit
- `git tag -l "vX.Y.Z"` shows the tag
- Release URL from `gh release view vX.Y.Z --json url -q .url`
