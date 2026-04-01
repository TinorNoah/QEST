# ----------------------------------------------------------------
# COMBINED ZSH CONFIGURATION
# --- Shell Options, History & Keybindings ---
HISTFILE=~/.config/zsh/.histfile
HISTSIZE=5000
SAVEHIST=100000
setopt autocd extendedglob
  unsetopt beep
  bindkey -v # Use vi keybindings in command mode

  # --- Exports ---
  # This makes sure the shell can find commands like 'starship'
  export PATH="$HOME/.cargo/bin:$PATH"
  export TERM="xterm-256color"

  # --- Modern Tool Inits ---
  # Zoxide (Smart cd)
  if command -v zoxide &> /dev/null; then eval "$(zoxide init zsh)"; fi
  # Atuin (Command history)
  if command -v atuin &> /dev/null; then eval "$(atuin init zsh)"; fi
  # Direnv (Environment switching)
  if command -v direnv &> /dev/null; then eval "$(direnv hook zsh)"; fi

  # --- Aliases ---
  # eza Aliases
  alias ls="eza --icons"
  alias l="eza -l --icons"
  alias la="eza -la --icons"
  alias lla="eza -la --icons"
  alias lt="eza --tree --icons"
  
  # bat alias
  if command -v bat &> /dev/null; then
      alias cat="bat --paging=never"
  elif command -v batcat &> /dev/null; then
      alias cat="batcat --paging=never"
  fi
  
  # zoxide alias
  alias cd="z"

  # Modern System Replacements
  alias find="fd"
  alias grep="rg"
  alias top="btop"
  alias du="dust"
  alias df="duf"
  alias ps="procs"
  alias ping="gping"
  alias dig="doggo"

  # --- Prompt Initialization ---
  # The manual prompt below is disabled because Starship is active.
  # PROMPT='%F{32}%n%f%F{166}@%f%F{64}%m:%F{166}%~%f%F{15}$%f '
  # RPROMPT='%F{15}(%F{166}%D{%H:%M}%F{15})%f'

  # Starship Prompt
  eval "$(starship init zsh)"

  # FZF Keybindings
  source /usr/share/doc/fzf/examples/key-bindings.zsh

  # --- Zsh Completion System ---
  autoload -U compinit && compinit
  # fzf-tab must be sourced after compinit
  source ~/.zsh/fzf-tab/fzf-tab.plugin.zsh

  # --- Plugins & Tools ---
  # Zsh Autosuggestions
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  
  # --- Fast Syntax Highlighting ---
  # Should usually be sourced at the end
  source ~/.zsh/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
