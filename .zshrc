# =============================================================================
# QEST — Zsh Configuration
# =============================================================================

# --- History ---
HISTFILE=~/.config/zsh/.histfile
HISTSIZE=5000
SAVEHIST=100000
mkdir -p "${HISTFILE:h}"   # ensure the directory exists before zsh tries to write it

# --- Shell Options & Keybindings ---
setopt autocd extendedglob
unsetopt beep
bindkey -v  # vi keybindings

# --- PATH & Exports ---
export PATH="$HOME/.cargo/bin:$PATH"
export TERM="xterm-256color"

# Homebrew (Linuxbrew) — must be evaluated early so all brew-installed
# binaries are on PATH before the aliases and tool inits below run.
if [[ -d /home/linuxbrew/.linuxbrew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# --- Modern Tool Inits ---
if command -v zoxide &>/dev/null; then eval "$(zoxide init zsh)";  fi
if command -v atuin  &>/dev/null; then eval "$(atuin init zsh)";   fi
if command -v direnv &>/dev/null; then eval "$(direnv hook zsh)";  fi

# --- Aliases ---

# eza
alias ls="eza --icons"
alias l="eza -l --icons"
alias la="eza -la --icons"
alias lla="eza -la --icons"
alias lt="eza --tree --icons"

# bat  (Debian/Ubuntu apt names the binary 'batcat')
if   command -v bat    &>/dev/null; then alias cat="bat --paging=never"
elif command -v batcat &>/dev/null; then alias cat="batcat --paging=never"
fi

# fd  (Debian/Ubuntu apt names the binary 'fdfind')
if   command -v fd     &>/dev/null; then alias find="fd"
elif command -v fdfind &>/dev/null; then alias find="fdfind"
fi

# gdu  (Homebrew Linux installs it as 'gdu-go' to avoid a conflict with
#       GNU coreutils' du — create a transparent alias when that is the case)
if   command -v gdu    &>/dev/null; then : # already on PATH as 'gdu'
elif command -v gdu-go &>/dev/null; then alias gdu="gdu-go"
fi

# zoxide
alias cd="z"

# Modern system replacements
alias grep="rg"
alias top="btop"
alias du="dust"
alias df="duf"
alias ps="procs"
alias ping="gping"
alias dig="doggo"

# --- Prompt ---
eval "$(starship init zsh)"

# --- FZF Key-bindings ---
# The key-bindings file lives in a different location depending on how fzf
# was installed.  We try every known path and source the first one found.
for _fzf_kb in \
  /usr/share/doc/fzf/examples/key-bindings.zsh \
  /usr/share/fzf/key-bindings.zsh \
  /home/linuxbrew/.linuxbrew/opt/fzf/shell/key-bindings.zsh \
  /opt/homebrew/opt/fzf/shell/key-bindings.zsh \
  /usr/local/opt/fzf/shell/key-bindings.zsh; do
  [[ -f "$_fzf_kb" ]] && source "$_fzf_kb" && break
done
unset _fzf_kb

# --- Zsh Completion System ---
autoload -U compinit && compinit

# fzf-tab must be sourced after compinit
source ~/.zsh/fzf-tab/fzf-tab.plugin.zsh

# --- Zsh Autosuggestions ---
# Same story as fzf — the plugin lands in a different directory depending on
# the distro package manager or Homebrew.
for _zsh_as in \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /home/linuxbrew/.linuxbrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh; do
  [[ -f "$_zsh_as" ]] && source "$_zsh_as" && break
done
unset _zsh_as

# --- Fast Syntax Highlighting ---
# Must be sourced last.
source ~/.zsh/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
