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

  # --- Plugins & Tools ---
  # Zsh Autosuggestions
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  # Zoxide (Smart cd)
  eval "$(zoxide init zsh)"

  # --- Aliases ---
  # lsd Aliases
  alias ls="lsd"
  alias l="lsd -l"
  alias la="lsd -a"
  alias lla="lsd -la"
  alias lt="lsd --tree"
  # bat alias (use batcat on Ubuntu)
  alias cat="batcat --paging=never"
  # zoxide alias
  alias cd="z"

  # --- Prompt Initialization ---
  # The manual prompt below is disabled because Starship is active.
  # PROMPT='%F{32}%n%f%F{166}@%f%F{64}%m:%F{166}%~%f%F{15}$%f '
  # RPROMPT='%F{15}(%F{166}%D{%H:%M}%F{15})%f'

  # Starship Prompt
  eval "$(starship init zsh)"

  # FZF Keybindings
  source /usr/share/doc/fzf/examples/key-bindings.zsh

  # --- Zsh Syntax Highlighting (MUST BE SOURCED LAST) ---
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  # --- Zsh Completion System ---
  # Autocomplete plugin must be sourced before compinit
  source ~/.zsh/zsh-autocomplete/zsh-autocomplete.plugin.zsh
  autoload -U compinit && compinit

  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion