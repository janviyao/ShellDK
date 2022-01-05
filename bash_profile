# .bash_profile

# Get the aliases and functions
if [ -f "${HOME}/.bashrc" ] ; then
    source "${HOME}/.bashrc"
fi

# User specific environment and startup programs
export GOPATH=$HOME/.local
export GOROOT=$GOPATH/go
export PATH=$PATH:$HOME/.local/bin:$GOROOT/bin
