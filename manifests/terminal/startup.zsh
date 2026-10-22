# Workspace Dev: criado somente quando não existe .zshrc.
[[ ! -r "$HOME/.config/config-workplace-terminal/bootstrap.zsh" ]] || source "$HOME/.config/config-workplace-terminal/bootstrap.zsh"
[[ ! -r "$HOME/.config/config-workplace-terminal/zshrc" ]] || source "$HOME/.config/config-workplace-terminal/zshrc"
