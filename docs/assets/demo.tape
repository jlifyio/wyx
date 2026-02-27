# wyx Demo GIF — Terminal Recording Script
# Tool: vhs (https://github.com/charmbracelet/vhs)
# Usage: cd /path/to/wyx-example && vhs /path/to/wyx/docs/assets/demo.tape
#
# Prerequisites:
#   1. Clone wyx-example: git clone https://github.com/jlifyio/wyx-example
#   2. Install vhs: brew install charmbracelet/tap/vhs (macOS) or go install github.com/charmbracelet/vhs@latest
#   3. Install wyx plugin in Claude Code first
#
# What this records:
#   Beat 1: Show a concept spec (the "what you write")
#   Beat 2: Run drift detection (the "what it finds")
#   Beat 3: Show the boundary violation it caught

Output docs/assets/demo.gif
Set FontSize 15
Set Width 1000
Set Height 500
Set Theme "Catppuccin Mocha"
Set Padding 20
Set TypingSpeed 40ms
Set Shell bash

# ─── Beat 1: Show the spec (4s) ───────────────────────

Type "# What does the payments module promise?"
Enter
Sleep 500ms

Type "cat src/payments/CONCEPT.md | head -20"
Enter
Sleep 3s

# ─── Beat 2: Run drift detection (8s) ─────────────────

Type "# Let's check if the code matches the spec..."
Enter
Sleep 500ms

Type "claude -p '/wyx:concept drift src/payments/'"
Enter
Sleep 7s

# ─── Beat 3: Show the violation (5s) ──────────────────

Type "# The boundary violation wyx found:"
Enter
Sleep 500ms

Type "head -5 src/payments/service.ts"
Enter
Sleep 4s

# ─── End ──────────────────────────────────────────────

Type "# Spec says: use getOrderTotal() service API"
Enter
Type "# Code does: import { findOrder } from orders/repository"
Enter
Type "# wyx catches this automatically."
Enter
Sleep 3s
