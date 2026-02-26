if status is-interactive
# Commands to run in interactive sessions can go here
end

function fish_greeting
    fastfetch
end

# Aliases

alias grep "grep --color=auto"
alias cat "bat --style=plain --paging=never"
alias ls "exa --group-directories-first"
alias tree "exa -T"
