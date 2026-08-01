# ~/.bashrc - NovaOS default user shell config

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# === Prompt (modern, with git branch) ===
parse_git_branch() {
    git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}
PS1='\[\e[1;35m\]\u@\h\[\e[0m\] \[\e[1;34m\]\w\[\e[0m\]\[\e[1;33m\]$(parse_git_branch)\[\e[0m\] \$ '

# === Aliases ===
alias ls='ls --color=auto --group-directories-first'
alias ll='ls -lah --group-directories-first'
alias la='ls -A --group-directories-first'
alias l='ls -CF --group-directories-first'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias update='novaos-update'
alias doctor='novaos-doctor'
alias store='novaos-store'
alias install-novaos='novaos-installer'

# === History ===
HISTCONTROL=ignoreboth:erasedups
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend
shopt -s checkwinsize

# === Color man pages ===
export LESS_TERMCAP_mb=$'\e[1;32m'
export LESS_TERMCAP_md=$'\e[1;32m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[1;44;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;4;31m'

# === Editor ===
export EDITOR=nano
export VISUAL=nano
export PAGER=less

# === Path additions ===
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# === Welcome message ===
if [ -f /etc/motd ]; then cat /etc/motd; fi

# === NovaOS ASCII banner (only on first login of session) ===
if [ -z "$NOVAOS_BANNER_SHOWN" ]; then
    export NOVAOS_BANNER_SHOWN=1
    echo -e "\e[1;35m"
    echo "  ███╗   ██╗ ██████╗  ██████╗ ███╗   ██╗███████╗████████╗"
    echo "  ████╗  ██║██╔═══██╗██╔═══██╗████╗  ██║██╔════╝╚══██╔══╝"
    echo "  ██╔██╗ ██║██║   ██║██║   ██║██╔██╗ ██║█████╗     ██║   "
    echo "  ██║╚██╗██║██║   ██║██║   ██║██║╚██╗██║██╔══╝     ██║   "
    echo "  ██║ ╚████║╚██████╔╝╚██████╔╝██║ ╚████║███████╗   ██║   "
    echo "  ╚═╝  ╚═══╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚══════╝   ╚═╝   "
    echo -e "\e[0m"
fi
