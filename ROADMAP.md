# QEST Roadmap (Go TUI Track)

This roadmap documents both:

- what is already implemented in the Go migration
- what is planned for upcoming `v0.x` releases

## Current state

Implemented:

- bootstrap downloader with checksum verification in [`get.qest.sh`](./get.qest.sh)
- Go installer entrypoint in [`cmd/qest/main.go`](./cmd/qest/main.go)
- full-screen wizard path (TTY) + plain fallback (`--no-gum` / non-TTY)
- phase-based install orchestration with summary status
- Cloudflare Worker bootstrap serving and fallback response messaging
- per-tool TOML catalog in [`manifests/tools/`](./manifests/tools)
- CI + release workflow scaffolding for static binaries

## Versioning policy

QEST is currently pre-1.0 and follows:

- `v0.1` -> validated default set
- `v0.2` -> validated extended optional set
- `v0.3` -> advanced/experimental staged set

No batch is promoted by default until it passes cross-OS validation gates.

## Tool rollout batches

### v0.1 (default validated set)

Shell/core:

- `zsh`, `starship`, `zsh-autosuggestions`, `fzf`, `zoxide`

Essentials:

- `bat`, `ripgrep`, `fd`, `jq`, `btop`, `eza`, `git-delta`

Editor/workflow baseline:

- `helix`, `zellij`, `lazygit`

Validation gate:

- `tests/verify.sh` passes for all `v0.1` tools on Ubuntu/Fedora/Arch Docker containers after Go binary install.

### v0.2 (extended optional set)

Shell/env:

- `direnv`, `atuin`, `nushell`, `chezmoi`, `age`

Files/data:

- `yazi`, `broot`, `duf`, `procs`, `dust`, `gdu`, `yq`, `sd`

Network/dev:

- `xh`, `gping`, `doggo`, `lazydocker`, `gitleaks`

Validation gate:

- install + binary checks pass on Ubuntu/Fedora/Arch
- fallback-source validation for non-native tools

### v0.3 (advanced/experimental staged set)

Text/analysis:

- `lnav`, `jless`, `dasel`, `visidata`, `choose-rust`, `logdy`

Ops/security and utility:

- `termshark`, `bandwhich`, `atac`, `asciinema`, `tealdeer`, `navi`, `grex`

Special-case installer candidates:

- `sysz`, `moulti`, `czkawka`, `erdtree`, `s5cmd`, `rclone`

Validation gate:

- can remain opt-in/experimental until all supported OS checks pass

## Manifest-driven catalog rules

Every tool is defined in one TOML file under `manifests/tools/` with:

- `id`
- `category`
- `tier`
- per-OS `install_source`
- `validation_status`

Optional:

- per-OS package names
- binary aliases
- notes / special installer flags

This enables adding tools without changing installer code.

## CI/test roadmap

Current:

- ShellCheck bootstrap/scripts
- `go build` and `go test`
- distro Docker matrix

Planned additions:

- per-tool batch validation jobs
- promotion checks (`planned` -> `validated`) enforced in CI
- release candidate checks before enabling new defaults

## Operational runbook (planned hardening)

- release:
  - tag `v*`, publish static binaries + checksums
- rollback:
  - keep prior release artifacts and allow bootstrap fallback
- incident response:
  - worker upstream failure returns clear fallback command
  - direct GitHub raw bootstrap remains available
