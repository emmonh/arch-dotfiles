#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

PS1='[\u@\h \W]\$ '

export PATH="$HOME/.local/bin:$PATH"

# Enable IMF
export GTK_IM_MODULE=wayland
export XMODIFIERS=@im=ibus
export QT_IM_MODULES=ibus
export QT_IM_MODULE=ibus

