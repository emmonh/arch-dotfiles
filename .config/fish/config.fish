if status is-interactive
# Commands to run in interactive sessions can go here
end

# ==============================
# Aliases
# ==============================
# Python venv
alias py "$HOME/.venv/bin/python"
alias pip "$HOME/.venv/bin/pip"

# Tools
alias grep "grep --color=auto"
alias cat "bat --style=plain --paging=never" # Requires bat
alias ls "exa --group-directories-first" # Requires exa
alias tree "exa -T" # Requires exa
alias mid "$HOME/.venv/bin/markitdown"

alias ff "fastfetch -c '$HOME/.config/fastfetch/config.jsonc'"

# ==============================
# Env vars
# ==============================
set -x PATH $PATH $HOME/.local/bin

# ==============================
# Greeting
# ==============================
function fish_greeting
    ff
end


