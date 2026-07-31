# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="agnosterzak"

plugins=(
    git
    archlinux
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# Check archlinux plugin commands here
# https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/archlinux

# Display custom PIXI-ARCH Fastfetch (Adaptive Logo Layout + Paleta Dinámica)
python3 $HOME/.config/fastfetch/random-logo-colors.py
cols=$(tput cols 2>/dev/null || echo 80)
if [ "$cols" -lt 100 ]; then
    fastfetch -c $HOME/.config/fastfetch/config-pixi-micro.jsonc
else
    fastfetch -c $HOME/.config/fastfetch/config-pixi.jsonc
fi

# Set-up icons for files/directories in terminal using lsd
alias ls='lsd'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lt='ls --tree'

# Set-up FZF key bindings (CTRL R for fuzzy history finder)
source <(fzf --zsh)

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
