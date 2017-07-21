# ~/.bashrc: executed by bash(1) for non-login shells.
export PS1='\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
#export PS1='\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '

# some more ls aliases
alias ls='ls --color'
alias ll='ls --color -alF'
alias llt='ls --color -altF'

