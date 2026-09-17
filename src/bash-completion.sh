# bash completion for cmdsync

# to enable bash completion for cmdsync, you can either
# 1) copy this file to /usr/share/bash-completion/completions/cmdsync, or
# 2) append the line 'source <path-to-this-file>' to ~/.bash_completion


_cmdsync () {

  local cur prev
  local options='--cmd --src --dest --ignore --dry-run --backup --suffix'
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD-1]}

  case $prev in
    'cmdsync')
      COMPREPLY=( $(compgen -W "${options}" -- ${cur}) )
      compopt +o nospace
      ;;
    '--cmd' | '--suffix')
      COMPREPLY=()
      compopt +o nospace
      ;;
    '--src' | '--dest' | '--ignore' | '--backup')
      COMPREPLY=( $(compgen -f -- ${cur}) )
      ;;
    *)
      COMPREPLY=( $(compgen -W "${options}" -- ${cur}) )
      compopt +o nospace
      ;;
  esac

  return 0
}

complete -o nospace -F _cmdsync cmdsync

