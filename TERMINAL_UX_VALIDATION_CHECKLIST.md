# Terminal UX Validation Checklist

Use this checklist before release to verify clarity and consistency across QEST terminal flows.

## Core scenarios

- [ ] Interactive wizard in TTY (`go run ./cmd/qest`)
- [ ] Plain prompt flow (`go run ./cmd/qest --no-gum`)
- [ ] Non-interactive defaults (`go run ./cmd/qest --yes --no-gum`)
- [ ] Dry-run behavior (`go run ./cmd/qest --dry-run --yes --no-gum`)
- [ ] `NO_COLOR=1` mode in both wizard and script output

## Interaction consistency

- [ ] Every wizard step shows key hints with consistent wording
- [ ] Back navigation uses `B/Esc` consistently where supported
- [ ] Confirm step clearly distinguishes install vs cancel
- [ ] Plain mode prompts show defaults and clear confirmation summary

## Message consistency

- [ ] Script output consistently uses `[INFO]`, `[WARN]`, `[ERROR]`, `[SUCCESS]`
- [ ] Warnings are recoverable and include fallback behavior
- [ ] Blocking errors include explicit next actions
- [ ] Dry-run output clearly states no system changes are made

## Failure and recovery checks

- [ ] Network failure path shows actionable retry guidance
- [ ] Dotfiles clone/update failure falls back cleanly to bundled defaults
- [ ] Package manager partial failure warns with log location (`/tmp/qest-install.log`)
- [ ] Unsupported/missing prerequisites provide concrete remediation steps

## Final acceptance

- [ ] No conflicting key hints or prompt vocabulary
- [ ] No ambiguous errors without recovery guidance
- [ ] README terminal UX docs match live behavior
