# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
alias k='kubectl'
alias kg='kubectl get'
alias kgp='kubectl get pods'
alias kgn='kubectl get nodes'
alias kd='kubectl describe'
alias ll='ls -ltra'
alias k='kubectl'
alias kg='kubectl get'
alias kgp='kubectl get pods'
alias kgn='kubectl get nodes'
alias kd='kubectl describe'
alias ll='ls -ltra'
alias k='kubectl'
alias kg='kubectl get'
alias kgp='kubectl get pods'
alias kgn='kubectl get nodes'
alias kd='kubectl describe'
alias ll='ls -ltra'
export CALICO_CONFIG="$HOME/.kube/calicoctl.cfg"

tc() {
  local namespace="dev1"
  local TIMEOUT=5  # Set global timeout to 5 seconds

  # Case 1: Connect to Pod Shell
  if [ $# -eq 1 ]; then
    local pod_prefix="$1"
    local pod_name=$(kubectl get pods -n "$namespace" --no-headers -o custom-columns=":metadata.name" | grep "^${pod_prefix}-" | head -n 1)

    if [ -z "$pod_name" ]; then
      echo "Error: No pod found with prefix '$pod_prefix' in namespace $namespace"
      return 1
    fi

    echo "Connecting to pod: $pod_name"
    timeout $TIMEOUT kubectl exec -it -n "$namespace" "$pod_name" -- /bin/sh

  # Case 2: Check connectivity
  elif [ $# -eq 3 ]; then
    local pod_prefix="$1"
    local target="$2"  # Service name or IP address
    local port="$3"

    # Validate port is a number
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
      echo "Error: Port must be a number"
      return 1
    fi

    # Find the pod
    local pod_name=$(kubectl get pods -n "$namespace" --no-headers -o custom-columns=":metadata.name" | grep "^${pod_prefix}-" | head -n 1)
    if [ -z "$pod_name" ]; then
      echo "Error: No pod found with prefix '$pod_prefix' in namespace $namespace"
      return 1
    fi

    # Determine if target is IP or service name
    local target_address
    if [[ "$target" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      target_address="$target"
    else
      # If it's a service name, form FQDN
      target_address="${target}.${namespace}.svc.cluster.local"
    fi

    echo "Checking connectivity from pod: $pod_name to ${target_address}:${port} (timeout: ${TIMEOUT}s)"

        # Run connectivity test with timeout
    timeout $TIMEOUT kubectl exec -n "$namespace" "$pod_name" -- sh -c "
      if command -v nc >/dev/null 2>&1; then
        timeout $TIMEOUT nc -zvw $TIMEOUT ${target_address} ${port}
      else
        echo 'Warning: nc not found, trying /dev/tcp method...'
        timeout $TIMEOUT bash -c \"</dev/tcp/${target_address}/${port}\" 2>/dev/null
        if [ \$? -eq 0 ]; then
          echo \"Port ${port} is open\"
        else
          echo \"Port ${port} is closed or unreachable\"
          exit 1
        fi
      fi
    "
    RESULT=$?
    
    # Check for timeout
    if [ $RESULT -eq 124 ]; then
      echo "Error: Connection timed out from $pod_name to ${target_address}:${port}"
    elif [ $RESULT -ne 0 ]; then
      echo "Error: Cannot connect from $pod_name to ${target_address}:${port}"
    fi

  # Invalid usage
  else
    echo "Usage:"
    echo "  Connect to pod:        tc <pod-prefix>"
    echo "  Check port connectivity: tc <pod-prefix> <service-name-or-ip> <port>"
    return 1
  fi
}