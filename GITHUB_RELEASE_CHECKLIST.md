# GitHub Release Checklist

Use this checklist for each QEST patch/minor release.

## Pre-release validation

- [ ] Confirm working tree is clean (`git status`).
- [ ] Run tests (`go test ./...`).
- [ ] Validate manifests (`go run ./cmd/qest --validate-manifests`).
- [ ] Build installer binary (`go build ./cmd/qest`).
- [ ] Verify docs reflect user-visible changes (`README.md`, troubleshooting notes).

## Git tasks

- [ ] Stage release-related changes.
- [ ] Commit with conventional commit format.
- [ ] Push to `origin/main`.
- [ ] Confirm branch is synced with remote.

## GitHub release tasks

- [ ] Pick next semantic version tag (for example, `v0.1.6`).
- [ ] Create GitHub release from `main` with concise highlights.
- [ ] Link included commit(s) and user-impact summary in notes.
- [ ] Confirm release URL is accessible and marked correctly (`Latest` when appropriate).

## Post-release checks

- [ ] Smoke-test install path (`curl -fsSL https://install.brainafk.in | bash` guidance remains valid).
- [ ] Confirm troubleshooting section matches current behavior.
- [ ] Announce/share release notes in project channels (issue, discussion, or changelog).
