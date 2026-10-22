# Padrão versionado para novas instalações; não carregar no startup pessoal.
[[ -z "${CW_TERMINAL_BOOTSTRAP_LOADED:-}" ]] || return 0
[[ -r "$ZSH/oh-my-zsh.sh" ]] || return 0
typeset -g CW_TERMINAL_BOOTSTRAP_LOADED=1
# Substituído pelo instalador a partir do manifesto de dados revisado.
ZSH_THEME="__CW_PREFERRED_THEME__"
plugins=(git)
zstyle ':omz:update' mode disabled
source "$ZSH/oh-my-zsh.sh"
