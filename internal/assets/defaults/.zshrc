HISTFILE=~/.config/zsh/.histfile
HISTSIZE=5000
SAVEHIST=100000
mkdir -p "${HISTFILE:h}"

setopt autocd extendedglob
unsetopt beep
bindkey -v

export TERM="xterm-256color"

if [[ -d /home/linuxbrew/.linuxbrew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

if command -v zoxide &>/dev/null; then eval "$(zoxide init zsh)"; fi
if command -v atuin  &>/dev/null; then eval "$(atuin init zsh)"; fi
if command -v direnv &>/dev/null; then eval "$(direnv hook zsh)"; fi

alias ls="eza --icons"
alias l="eza -l --icons"
alias la="eza -la --icons"
alias grep="rg"
alias top="btop"

if command -v bat &>/dev/null; then
  alias cat="bat --paging=never"
elif command -v batcat &>/dev/null; then
  alias cat="batcat --paging=never"
fi

if command -v fd &>/dev/null; then
  alias find="fd"
elif command -v fdfind &>/dev/null; then
  alias find="fdfind"
fi

if command -v gdu-go &>/dev/null && ! command -v gdu &>/dev/null; then
  alias gdu="gdu-go"
fi

if command -v starship &>/dev/null; then
  eval "$(starship init zsh)"
fi

autoload -U compinit && compinit

[[ -f ~/.zsh/fzf-tab/fzf-tab.plugin.zsh ]] && source ~/.zsh/fzf-tab/fzf-tab.plugin.zsh
[[ -f ~/.zsh/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh ]] && source ~/.zsh/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
