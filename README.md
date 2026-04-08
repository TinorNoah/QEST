<div align="center">
  <h1>QEST</h1>
  <p><strong>Quite Effective Setup Tool</strong></p>
  <p>Single-command Linux bootstrap with a full interactive terminal wizard.</p>
</div>

<br>

![QEST hero preview](./hero.png)

## What QEST is

QEST installs a modern shell environment on fresh Linux machines with one command:

```bash
curl -fsSL https://install.brainafk.in | bash
```

The bootstrap script stays tiny, downloads a prebuilt `qest` binary, verifies checksums, and runs the installer wizard.

## Architecture

1. **Bootstrap script**: [`get.qest.sh`](./get.qest.sh)
   - Detects distro + architecture.
   - Checks `curl`, `sudo`, internet access.
   - Downloads `qest-linux-amd64` or `qest-linux-arm64` from GitHub Releases.
   - Verifies SHA256 and executes the binary.
2. **Installer binary**: [`cmd/qest/main.go`](./cmd/qest/main.go)
   - Full-screen Bubble Tea wizard (TTY mode).
   - Plain fallback for `--no-gum` / non-TTY.
   - Phase-based install engine with per-tool source resolution.
3. **Tool catalog**: [`manifests/tools/`](./manifests/tools)
   - One TOML file per tool.
   - Encodes category, tier, install source per OS, package mapping, validation state.
4. **Cloudflare Worker**: [`cloudflare-worker/src/index.js`](./cloudflare-worker/src/index.js)
   - Serves the latest bootstrap script from GitHub.
   - Returns actionable fallback command if upstream fetch fails.

## Current support

- **OS**: Ubuntu/Debian, Fedora, Arch/Manjaro
- **CPU**: amd64, arm64
- **Modes**:
  - Interactive TTY -> full-screen wizard
  - `--yes` -> non-interactive install with defaults
  - `--dry-run` -> preview commands
  - `--no-gum` -> plain sequential mode

## v0.1 validated default set

QEST currently defaults to a small cross-OS validated set:

- shell/core: `zsh`, `starship`, `zsh-autosuggestions`, `fzf`, `zoxide`
- essentials: `bat`, `ripgrep`, `fd`, `jq`, `btop`, `eza`, `git-delta`
- editor/workflow: `helix`, `zellij`, `lazygit`
- config: bundled `.zshrc` + `starship.toml` with backup/restore

Verification gate:

- [`tests/verify.sh`](./tests/verify.sh) validates v0.1 tooling/config presence.

## Tool source strategy

Each tool is resolved per OS using a source policy from TOML manifests:

- `native` -> apt/dnf/pacman
- `brew` -> Homebrew fallback (primarily Ubuntu/Fedora for missing packages)
- `unsupported` -> omitted from current install plan and marked for future rollout

## Run locally from repo

```bash
# interactive
go run ./cmd/qest

# non-interactive defaults
go run ./cmd/qest --yes --no-gum

# dry-run
go run ./cmd/qest --dry-run --yes --no-gum
```

## CI and release

- CI: [`.github/workflows/ci.yml`](./.github/workflows/ci.yml)
  - ShellCheck for bootstrap/scripts
  - `go build` and `go test`
  - Docker matrix smoke checks
- Tagged release: [`.github/workflows/release.yml`](./.github/workflows/release.yml)
  - static binaries (`CGO_ENABLED=0`) for linux/amd64 and linux/arm64
  - checksum files
  - release assets:
    - `qest-linux-amd64`
    - `qest-linux-amd64.sha256`
    - `qest-linux-arm64`
    - `qest-linux-arm64.sha256`

## What has been done

- Cloudflare worker route set to `install.brainafk.in`.
- Bootstrap switched from git clone flow to binary+checksum flow.
- Go installer foundation implemented with:
  - wizard selection model
  - plain fallback mode
  - phase execution
  - per-tool TOML manifest loading
- v0.1 tool manifests created under [`manifests/tools/`](./manifests/tools).

## Planned next (v0.x roadmap)

See full plan in [`ROADMAP.md`](./ROADMAP.md). High-level batches:

- `v0.1`: validated default set (current target)
- `v0.2`: extended opt-in set after cross-OS validation
- `v0.3`: advanced/experimental set with staged promotion

Track progress:

- [v0.1 milestone](https://github.com/TinorNoah/QEST/milestone/1)
- [v0.1 release tracker](https://github.com/TinorNoah/QEST/issues/9)

## Troubleshooting

- If `install.brainafk.in` fails temporarily:
  - use direct fallback:
  ```bash
  curl -fsSL https://raw.githubusercontent.com/TinorNoah/QEST/main/get.qest.sh | bash
  ```
- If `sudo` prompts fail:
  ```bash
  sudo -v
  ```
- For plain mode in constrained terminals:
  ```bash
  go run ./cmd/qest --no-gum
  ```

## Wiki

Extended implementation notes and operational docs live in the project wiki:

- [QEST Wiki Home](https://github.com/TinorNoah/QEST/wiki)
