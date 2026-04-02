# 🗺️ QEST Roadmap

This document outlines the planned evolution of QEST across phased milestones.
Every item is grounded in a concrete gap or limitation observed in the current codebase.
Community feedback and pull requests are welcome on any item.

> **Current version:** v1.0 — single-pass installer, three distros, Docker test suite.

---

## Phase 1 — Stability & CI `v1.1`
*Goal: make the current installer bulletproof before adding new features.*

### 🐛 Bug Fixes

- **Fix hardcoded Debian paths in `.zshrc`**
  The shipped `.zshrc` sources `/usr/share/doc/fzf/examples/key-bindings.zsh` and
  `/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh` — paths that only exist on
  Debian/Ubuntu. On Arch these live under `/usr/share/fzf/` and
  `/usr/share/zsh/plugins/zsh-autosuggestions/` respectively. The config setup step
  (`04_config_setup.sh`) should write a distro-aware `.zshrc` instead of copying a
  single static file.

- **Create `~/.config/zsh/` before writing `HISTFILE`**
  `.zshrc` sets `HISTFILE=~/.config/zsh/.histfile` but `04_config_setup.sh` never
  creates that directory, causing zsh to silently drop history on first login.

- **Add `alias gdu="gdu-go"` for Debian/Fedora users**
  Homebrew on Linux renames the `gdu` binary to `gdu-go` to avoid a conflict with
  GNU coreutils' `du`. The alias is not currently written to `.zshrc`, so the `duf`
  and `gdu` aliases listed in the README don't work out of the box on those distros.

- **Fix `moulti` installation on Debian/Fedora**
  The Homebrew formula for `moulti` fails in minimal environments. Replace the
  `brew_core.txt` entry with a `pipx install moulti` step in `03_install_extras.sh`,
  guarded by a `pipx`/`pip3` availability check with an automatic fallback installer.

- **Add `erd` alias for `erdtree`**
  Since v3.x the `erdtree` binary is called `erd`. Update `.zshrc` and any
  documentation that references `et` or `erdtree`.

### ⚡ Performance

- **Batch Homebrew installs**
  `03_install_extras.sh` currently calls `brew install <pkg>` in a loop — one network
  round-trip per package. A single `brew install $(cat manifests/brew_core.txt | tr '\n' ' ')`
  call cuts install time by ~60 % (e.g. from 20 min → ~8 min on Ubuntu).

- **Batch `yay`/`pacman` installs**
  `02_install_arch.sh` already batches the pacman call correctly. Ensure `yay` also
  receives the full package list in one invocation rather than being called iteratively.

### 🤖 CI / CD

- **GitHub Actions workflow**
  Add `.github/workflows/test.yml` that triggers on every push and pull request,
  running `./test_docker.sh --parallel` against all three distros. Publish a test
  status badge to the README.

- **ShellCheck linting**
  Add a second GitHub Actions job that runs `shellcheck` across all `.sh` files in
  `scripts/` and `tests/`. Enforce it as a required check on PRs.

- **Automated Docker image caching**
  Cache the base Docker layers in GitHub Actions using `actions/cache` to avoid
  re-downloading OS base images on every run.

---

## Phase 2 — Flexibility `v1.2`
*Goal: let users choose what gets installed instead of all-or-nothing.*

### 🎛️ Installation Profiles

Introduce a `--profile` flag with three built-in tiers:

| Profile | Description |
|---|---|
| `minimal` | Core shell (`zsh`, `fzf`, `bat`, `rg`, `fd`, `zoxide`) + config files only |
| `dev` | `minimal` + editors, git tools, language runtimes |
| `full` | Everything (current default behaviour) |

Profiles are defined as plain text manifests in `manifests/profiles/` so users can
create and version-control their own.

### ⚙️ Runtime Configuration File

Support an optional `~/.qestrc` (or `$QEST_CONFIG`) that pre-answers interactive
prompts and customises the tool selection — useful for scripted or headless deployments:

```ini
PROFILE=dev
INSTALL_HOMEBREW=yes
SET_DEFAULT_SHELL=yes
SKIP_PACKAGES=moulti,sysz
EXTRA_PACKAGES=neovim,tmux
```

### 🔁 Idempotent Re-runs & Resume on Failure

Track installed packages in a state file (`~/.local/share/qest/installed.json`).
On a re-run, skip already-installed tools and only retry failures, rather than
attempting the full install from scratch.

### 🔇 Non-interactive / Headless Mode

Add a `--yes` / `-y` flag that answers `Y` to every prompt, making QEST fully
scriptable without piping `yes ''` workarounds. Useful for provisioning scripts,
cloud-init, and CI environments.

---

## Phase 3 — Platform Expansion `v2.0`
*Goal: take QEST beyond the three current Linux distros.*

### 🍎 macOS Support

`01_os_detect.sh` currently exits immediately on macOS. QEST already depends on
Homebrew for the extended toolset — macOS is the natural next platform:

- Use `brew` as the primary package manager (replacing `apt`/`dnf`/`pacman`)
- Handle macOS-specific path differences (`/opt/homebrew` on Apple Silicon vs
  `/usr/local` on Intel)
- Resolve `bat`/`batcat`, `fd`/`fdfind` naming differences on macOS
- Add `macos.Dockerfile` (using `sickcodes/docker-osx` or a native runner in CI)

### 🪟 WSL2 Support

WSL2 is the dominant way Windows developers run Linux toolchains. Add explicit
WSL2 detection in `01_os_detect.sh` and handle WSL-specific edge cases:

- Windows interop PATH pollution (`/mnt/c/Windows/...` entries interfering with
  `command -v` lookups)
- `chsh` not working under WSL (default shell must be set via `/etc/passwd` or
  the Windows Terminal profile instead)
- `gping` and `termshark` requiring elevated privileges for raw sockets under WSL

### 🏗️ Additional Distro Support

- **openSUSE / Tumbleweed** — `zypper`-based install path
- **Alpine Linux** — `apk`-based, useful for Docker-native environments
- **NixOS** — `home-manager` integration as an alternative delivery mechanism

---

## Phase 4 — Lifecycle Management `v2.1`
*Goal: QEST manages the environment after the initial install, not just during it.*

### 🔄 `qest update`

A subcommand that refreshes all tools installed by QEST to their latest versions:

```bash
qest update           # update everything
qest update eza bat   # update specific tools
```

Internally: `brew upgrade`, `yay -Syu`, `pacman -Syu`, re-pull zsh plugin repos.

### 🗑️ `qest uninstall`

A clean teardown that reverses the installation:

- Remove installed packages (distro-aware)
- Restore the `.zshrc` backup created by `04_config_setup.sh`
- Remove cloned zsh plugin directories (`~/.zsh/fzf-tab`, etc.)
- Restore the previous default shell via `chsh`

### 📊 `qest status`

A read-only health check that shows the installed version of each managed tool,
flags anything that is missing or outdated, and links to the relevant changelog:

```
Tool          Installed    Latest    Status
──────────────────────────────────────────
eza           0.18.21      0.18.21   ✔ up to date
bat           0.24.0       0.25.0    ↑ update available
helix         24.03        25.01     ↑ update available
moulti        —            0.9.0     ✘ not installed
```

---

## Phase 5 — Community & Ecosystem `v3.0`
*Goal: let the community extend QEST without forking it.*

### 🔌 Plugin System

A lightweight plugin interface that allows third-party tool sets to be added
without modifying core manifests:

```bash
# Install a community plugin
qest plugin add https://github.com/someone/qest-plugin-rust-dev

# List active plugins
qest plugin list
```

A plugin is a directory containing a `manifest.txt`, an optional `install.sh`
hook, and an optional `verify.sh` fragment that gets merged into the test suite.

### 👤 Dotfiles Integration

First-class integration with `chezmoi` (which QEST already installs) to manage
the `.zshrc`, `starship.toml`, and any other config files as a versioned dotfiles
repository rather than static copies.

### 🌐 Web-based Config Builder

A simple static site (e.g. hosted on GitHub Pages) where users can tick the tools
they want, pick a profile, and download a pre-generated `~/.qestrc` config file or
a custom `brew_core.txt` / `arch_core.txt` manifest — no coding required.

### 🔒 Supply Chain Security

- Pin tool versions in manifests and verify checksums where possible
- Add `gitleaks` pre-commit hook to the repo itself (QEST already installs
  `gitleaks` — use it to guard its own source)
- Sign releases with `age` (also already installed by QEST)

---

## Contributing

If you want to pick up any item on this roadmap, open an issue referencing it
before starting work so effort isn't duplicated. Items marked with a bug emoji
(🐛) are the highest priority and the easiest entry point for first-time contributors.

All contributions must pass `./test_docker.sh` locally before a PR is opened.