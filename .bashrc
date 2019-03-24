#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '

if [ -e ~/.bashrc.aliases ] ; then
   source ~/.bashrc.aliases
fi

if [ -e ~/.bash_profile ] ; then
   source ~/.bash_profile
fi

if [ -e ~/.bash_prompt ] ; then
   source ~/.bash_prompt
fi

BROWSER=/usr/bin/firefox
EDITOR=/usr/bin/nano
