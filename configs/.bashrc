#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '

## Modified commands
alias diff='colordiff'              # requires colordiff package
alias grep='grep --color=auto'

## ls
alias ls='ls -hF --color=auto'

## New commands
alias irqs='cat /proc/interrupts'
alias FFz='ps -eLo rtprio,cls,pid,pri,cmd | grep "FF" | sort'
alias RRz='ps -eLo rtprio,cls,pid,pri,cmd | grep "RR" | sort'
alias cpufreqs='watch grep \"cpu MHz\" /proc/cpuinfo'
alias mutter_settings='gjs /home/ninez/Winebox/bin/mutter_settings.js'

#GPG key / Git
export GPG_TTY=$(tty)

# WINE NSPA /bin
export PATH=/home/ninez/Winebox/bin:$PATH

