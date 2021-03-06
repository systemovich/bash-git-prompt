#!/bin/sh

function async_run()
{
  {
    $1 &> /dev/null
  }&
}

function git_prompt_dir()
{
  # assume the gitstatus.sh is in the same directory as this script
  # code thanks to http://stackoverflow.com/questions/59895
  if [ -z "$__GIT_PROMPT_DIR" ]; then
    local SOURCE="${BASH_SOURCE[0]}"
    while [ -h "$SOURCE" ]; do
      local DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
      SOURCE="$(readlink "$SOURCE")"
      [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
    done
    __GIT_PROMPT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  fi
}

function echoc() {
    echo -e "${1}$2${ResetColor}" | sed 's/\\\]//g'  | sed 's/\\\[//g'
}

function get_theme()
{
  local CUSTOM_THEME_FILE="${HOME}/.git-prompt-colors.sh"
  local DEFAULT_THEME_FILE="${__GIT_PROMPT_DIR}/themes/Default.bgptheme"

  if [[ -z ${GIT_PROMPT_THEME} ]]; then
    if [[ -r $CUSTOM_THEME_FILE ]]; then
      GIT_PROMPT_THEME="Custom"
      __GIT_PROMPT_THEME_FILE=$CUSTOM_THEME_FILE
    else
      GIT_PROMPT_THEME="Default"
      __GIT_PROMPT_THEME_FILE=$DEFAULT_THEME_FILE
    fi
  else
    if [[ "${GIT_PROMPT_THEME}" = "Custom" ]]; then
      GIT_PROMPT_THEME="Custom"
      __GIT_PROMPT_THEME_FILE=$CUSTOM_THEME_FILE
      
      if [[ ! (-r $__GIT_PROMPT_THEME_FILE) ]]; then
        GIT_PROMPT_THEME="Default"
        __GIT_PROMPT_THEME_FILE=$DEFAULT_THEME_FILE
      fi
    else
      local theme=""
      
      # use default theme, if theme was not found
      for themefile in `ls "$__GIT_PROMPT_DIR/themes"`; do
        if [[ "${themefile}" = "${GIT_PROMPT_THEME}.bgptheme" ]]; then
          theme=$GIT_PROMPT_THEME
        fi
      done

      if [[ "${theme}" = "" ]]; then
        GIT_PROMPT_THEME="Default"
      fi 

      __GIT_PROMPT_THEME_FILE="${__GIT_PROMPT_DIR}/themes/${GIT_PROMPT_THEME}.bgptheme"
    fi
  fi
}

function git_prompt_load_theme()
{
  get_theme
  local DEFAULT_THEME_FILE="${__GIT_PROMPT_DIR}/themes/Default.bgptheme"
  source "${DEFAULT_THEME_FILE}"
  source "${__GIT_PROMPT_THEME_FILE}"
}

function git_prompt_list_themes() 
{
  local oldTheme
  local oldThemeFile

  git_prompt_dir
  get_theme

  for themefile in `ls "$__GIT_PROMPT_DIR/themes"`; do
    local theme="$(basename $themefile .bgptheme)"

    if [[ "${GIT_PROMPT_THEME}" = "${theme}" ]]; then
      echoc ${Red} "*${theme}"
    else
      echo $theme 
    fi
  done

  if [[ "${GIT_PROMPT_THEME}" = "Custom" ]]; then
    echoc ${Magenta} "*Custom"
  else
    echoc ${Blue} "Custom"
  fi
}

function git_prompt_make_custom_theme() {
  if [[ -r "${HOME}/.git-prompt-colors.sh" ]]; then
    echoc ${Red} "You alread have created a custom theme!"
  else
    git_prompt_dir

    local base="Default"
    if [[ -n $1 && -r "${__GIT_PROMPT_DIR}/themes/${1}.bgptheme" ]]; then
      base=$1
      echoc ${Green} "Using theme ${Magenta}\"${base}\"${Green} as base theme!"
    else
      echoc ${Green} "Using theme ${Magenta}\"Default\"${Green} as base theme!"
    fi

    if [[ "${base}" = "Custom" ]]; then
      echoc ${Red} "You cannot use the custom theme as base"
    else
      echoc ${Green} "Creating new cutom theme in \"${HOME}/.git-prompt-colors.sh\""
      echoc ${DimYellow} "Please add ${Magenta}\"GIT_PROMPT_THEME=Custom\"${DimYellow} to your .bashrc to use this theme"
      if [[ "${base}" == "Default" ]]; then
        cp "${__GIT_PROMPT_DIR}/themes/Custom.bgptemplate" "${HOME}/.git-prompt-colors.sh"
      else
        cp "${__GIT_PROMPT_DIR}/themes/${base}.bgptheme" "${HOME}/.git-prompt-colors.sh"
      fi
    fi
  fi
}

# gp_set_file_var ENVAR SOMEFILE
#
# If ENVAR is set, check that it's value exists as a readable file.  Otherwise,
# Set ENVAR to the path to SOMEFILE, based on $HOME, $__GIT_PROMPT_DIR, and the
# directory of the current script.  The SOMEFILE can be prefixed with '.', or
# not.
#
# Return 0 (success) if ENVAR not already defined, 1 (failure) otherwise.

function gp_set_file_var() {
  local envar="$1"
  local file="$2"
  if eval "[[ -n \"\$$envar\" && -r \"\$$envar\" ]]" ; then # is envar set to a readable file?
    local basefile
    eval "basefile=\"\`basename \\\"\$$envar\\\"\`\""   # assign basefile
    if [[ "$basefile" = "$file" || "$basefile" = ".$file" ]]; then
      return 0
    fi
  else  # envar is not set, or it's set to a different file than requested
    eval "$envar="      # set empty envar
    gp_maybe_set_envar_to_path "$envar" "$HOME/.$file" "$HOME/$file" "$HOME/lib/$file" && return 0
    git_prompt_dir
    gp_maybe_set_envar_to_path "$envar" "$__GIT_PROMPT_DIR/$file" "${0##*/}/$file"     && return 0
  fi
  return 1
}

# gp_maybe_set_envar_to_path ENVAR FILEPATH ...
#
# return 0 (true) if any FILEPATH is readable, set ENVAR to it
# return 1 (false) if not

function gp_maybe_set_envar_to_path(){
  local envar="$1"
  shift
  local file
  for file in "$@" ; do
    if [[ -r "$file" ]]; then
      eval "$envar=\"$file\""
      return 0
    fi
  done
  return 1
}

# git_prompt_reset
#
# unsets selected GIT_PROMPT variables, causing the next prompt callback to
# recalculate them from scratch.

git_prompt_reset() {
  local var
  for var in GIT_PROMPT_DIR __GIT_PROMPT_COLORS_FILE __PROMPT_COLORS_FILE __GIT_STATUS_CMD GIT_PROMPT_THEME_NAME; do
    unset $var
  done
}

# gp_format_exit_status RETVAL
#
# echos the symbolic signal name represented by RETVAL if the process was 
# signalled, otherwise echos the original value of RETVAL

gp_format_exit_status() {
    local RETVAL="$1"
    local SIGNAL
    # Suppress STDERR in case RETVAL is not an integer (in such cases, RETVAL 
    # is echoed verbatim)
    if [ "${RETVAL}" -gt 128 ] 2>/dev/null; then
        SIGNAL=$(( ${RETVAL} - 128 ))
        kill -l "${SIGNAL}" 2>/dev/null || echo "${RETVAL}"
    else
        echo "${RETVAL}"
    fi
}

function git_prompt_config()
{
  #Checking if root to change output
  _isroot=false
  [[ $UID -eq 0 ]] && _isroot=true

  # There are two files related to colors:
  #
  #  prompt-colors.sh -- sets generic color names suitable for bash `PS1` prompt
  #  git-prompt-colors.sh -- sets the GIT_PROMPT color scheme, using names from prompt-colors.sh

  if gp_set_file_var __PROMPT_COLORS_FILE prompt-colors.sh ; then
    source "$__PROMPT_COLORS_FILE"        # outsource the color defs
  else
    echo 1>&2 "Cannot find prompt-colors.sh!"
  fi

  # source the user's ~/.git-prompt-colors.sh file, or the one that should be
  # sitting in the same directory as this script

  git_prompt_load_theme

  if [ $GIT_PROMPT_LAST_COMMAND_STATE = 0 ]; then
    LAST_COMMAND_INDICATOR="$GIT_PROMPT_COMMAND_OK";
  else
    LAST_COMMAND_INDICATOR="$GIT_PROMPT_COMMAND_FAIL";
  fi

  # replace _LAST_COMMAND_STATE_ token with the actual state
  GIT_PROMPT_LAST_COMMAND_STATE=$(gp_format_exit_status ${GIT_PROMPT_LAST_COMMAND_STATE})
  LAST_COMMAND_INDICATOR="${LAST_COMMAND_INDICATOR//_LAST_COMMAND_STATE_/${GIT_PROMPT_LAST_COMMAND_STATE}}"

  # Do this only once to define PROMPT_START and PROMPT_END

  if [[ -z "$PROMPT_START" || -z "$PROMPT_END" ]]; then

    if [[ -z "$GIT_PROMPT_START" ]] ; then
      if $_isroot; then
        PROMPT_START="$GIT_PROMPT_START_ROOT"
      else
        PROMPT_START="$GIT_PROMPT_START_USER"
      fi
    else
      PROMPT_START="$GIT_PROMPT_START"
    fi

    if [[ -z "$GIT_PROMPT_END" ]] ; then
      if $_isroot; then
        PROMPT_END="$GIT_PROMPT_END_ROOT"
      else
        PROMPT_END="$GIT_PROMPT_END_USER"
      fi
    else
      PROMPT_END="$GIT_PROMPT_END"
    fi
  fi

  # set GIT_PROMPT_LEADING_SPACE to 0 if you want to have no leading space in front of the GIT prompt
  if [[ "$GIT_PROMPT_LEADING_SPACE" = 0 ]]; then
    PROMPT_LEADING_SPACE=""
  else
    PROMPT_LEADING_SPACE=" "
  fi

  if [[ "$GIT_PROMPT_ONLY_IN_REPO" = 1 ]]; then
    EMPTY_PROMPT="$OLD_GITPROMPT"
  else
    local ps=""
    if [[ -n "$VIRTUAL_ENV" ]]; then
      VENV=$(basename "${VIRTUAL_ENV}")
      ps="${ps}${GIT_PROMPT_VIRTUALENV//_VIRTUALENV_/${VENV}}"
    fi
    if [[ -n "$CONDA_DEFAULT_ENV" ]]; then
      VENV=$(basename "${CONDA_DEFAULT_ENV}")
      ps="${ps}${GIT_PROMPT_VIRTUALENV//_VIRTUALENV_/${VENV}}"
    fi
    ps="$ps$PROMPT_START$($prompt_callback)$PROMPT_END"
    EMPTY_PROMPT="${ps//_LAST_COMMAND_INDICATOR_/${LAST_COMMAND_INDICATOR}}"
  fi

  # fetch remote revisions every other $GIT_PROMPT_FETCH_TIMEOUT (default 5) minutes
  GIT_PROMPT_FETCH_TIMEOUT=${1-5}
  if [[ -z "$__GIT_STATUS_CMD" ]] ; then          # if GIT_STATUS_CMD not defined..
    git_prompt_dir
    if ! gp_maybe_set_envar_to_path __GIT_STATUS_CMD "$__GIT_PROMPT_DIR/gitstatus.sh" ; then
      echo 1>&2 "Cannot find gitstatus.sh!"
    fi
    # __GIT_STATUS_CMD defined
  fi
}

function setLastCommandState() {
  GIT_PROMPT_LAST_COMMAND_STATE=$?
}

function we_are_on_repo() {
  if [[ -e "$(git rev-parse --git-dir 2> /dev/null)" ]]; then
    echo 1
  fi
  echo 0
}

function update_old_git_prompt() {
  local in_repo=$(we_are_on_repo)
  if [[ $GIT_PROMPT_OLD_DIR_WAS_GIT = 0 ]]; then
    OLD_GITPROMPT=$PS1
  fi
  
  GIT_PROMPT_OLD_DIR_WAS_GIT=$in_repo
}

function setGitPrompt() {
  update_old_git_prompt
  
  local repo=`git rev-parse --show-toplevel 2> /dev/null`
  if [[ ! -e "$repo" ]] && [[ "$GIT_PROMPT_ONLY_IN_REPO" = 1 ]]; then
    # we do not permit bash-git-prompt outside git repos, so nothing to do
    PS1="$OLD_GITPROMPT"
    return
  fi
  
  local EMPTY_PROMPT
  local __GIT_STATUS_CMD

  git_prompt_config

  if [[ ! -e "$repo" ]]; then
    PS1="$EMPTY_PROMPT"
    return
  fi

  local FETCH_REMOTE_STATUS=1
  if [[ "$GIT_PROMPT_FETCH_REMOTE_STATUS" = 0 ]]; then
    FETCH_REMOTE_STATUS=0
  fi

  unset GIT_PROMPT_IGNORE

  if [[ -e "$repo/.bash-git-rc" ]]; then
    source "$repo/.bash-git-rc"
  fi

  if [[ "$GIT_PROMPT_IGNORE" = 1 ]]; then
    PS1="$EMPTY_PROMPT"
    return
  fi

  if [[ "$FETCH_REMOTE_STATUS" = 1 ]]; then
    checkUpstream
  fi

  updatePrompt
}

function checkUpstream() {
  local GIT_PROMPT_FETCH_TIMEOUT
  git_prompt_config

  local FETCH_HEAD="$repo/.git/FETCH_HEAD"
  # Fech repo if local is stale for more than $GIT_FETCH_TIMEOUT minutes
  if [[ ! -e "$FETCH_HEAD"  ||  -e `find "$FETCH_HEAD" -mmin +$GIT_PROMPT_FETCH_TIMEOUT` ]]
  then
    if [[ -n $(git remote show) ]]; then
      (
        async_run "git fetch --quiet"
        disown -h
      )
    fi
  fi
}

function replaceSymbols()
{
  if [[ -z ${GIT_PROMPT_SYMBOLS_NO_REMOTE_TRACKING} ]]; then
    GIT_PROMPT_SYMBOLS_NO_REMOTE_TRACKING=L
  fi

	local VALUE=${1//_AHEAD_/${GIT_PROMPT_SYMBOLS_AHEAD}}
	local VALUE1=${VALUE//_BEHIND_/${GIT_PROMPT_SYMBOLS_BEHIND}}
  local VALUE2=${VALUE1//_NO_REMOTE_TRACKING_/${GIT_PROMPT_SYMBOLS_NO_REMOTE_TRACKING}}
	
	echo ${VALUE2//_PREHASH_/${GIT_PROMPT_SYMBOLS_PREHASH}}
}

function updatePrompt() {
  local LAST_COMMAND_INDICATOR
  local PROMPT_LEADING_SPACE
  local PROMPT_START
  local PROMPT_END
  local EMPTY_PROMPT
  local Blue="\[\033[0;34m\]"

  git_prompt_config

  export __GIT_PROMPT_IGNORE_STASH=${GIT_PROMPT_IGNORE_STASH}
  local -a GitStatus
  GitStatus=($("$__GIT_STATUS_CMD" 2>/dev/null))

  local GIT_BRANCH=$(replaceSymbols ${GitStatus[0]})
  local GIT_REMOTE="$(replaceSymbols ${GitStatus[1]})"
  if [[ "." == "$GIT_REMOTE" ]]; then
    unset GIT_REMOTE
  fi
  local GIT_STAGED=${GitStatus[2]}
  local GIT_CONFLICTS=${GitStatus[3]}
  local GIT_CHANGED=${GitStatus[4]}
  local GIT_UNTRACKED=${GitStatus[5]}
  local GIT_STASHED=${GitStatus[6]}
  local GIT_CLEAN=${GitStatus[7]}

  local NEW_PROMPT="$EMPTY_PROMPT"
  if [[ -n "$GitStatus" ]]; then
    local STATUS="${PROMPT_LEADING_SPACE}${GIT_PROMPT_PREFIX}${GIT_PROMPT_BRANCH}${GIT_BRANCH}${ResetColor}"

    # __add_status KIND VALEXPR INSERT
    # eg: __add_status  'STAGED' '-ne 0'

    __chk_gitvar_status() {
      local v
      if [[ "x$2" == "x-n" ]] ; then
        v="$2 \"\$GIT_$1\""
      else
        v="\$GIT_$1 $2"
      fi
      if eval "test $v" ; then
        if [[ $# -lt 2 || "$3" != '-' ]]; then
          __add_status "\$GIT_PROMPT_$1\$GIT_$1\$ResetColor"
        else
          __add_status "\$GIT_PROMPT_$1\$ResetColor"
        fi
      fi
    }

    __add_gitvar_status() {
      __add_status "\$GIT_PROMPT_$1\$GIT_$1\$ResetColor"
    }

    # __add_status SOMETEXT
    __add_status() {
      eval "STATUS=\"$STATUS$1\""
    }

    __chk_gitvar_status 'REMOTE'     '-n'
    __add_status        "$GIT_PROMPT_SEPARATOR"
    __chk_gitvar_status 'STAGED'     '-ne 0'
    __chk_gitvar_status 'CONFLICTS'  '-ne 0'
    __chk_gitvar_status 'CHANGED'    '-ne 0'
    __chk_gitvar_status 'UNTRACKED'  '-ne 0'
    __chk_gitvar_status 'STASHED'    '-ne 0'
    __chk_gitvar_status 'CLEAN'      '-eq 1'   -
    __add_status        "$ResetColor$GIT_PROMPT_SUFFIX"

    NEW_PROMPT=""
    if [[ -n "$VIRTUAL_ENV" ]]; then
      VENV=$(basename "${VIRTUAL_ENV}")
      NEW_PROMPT="$NEW_PROMPT${GIT_PROMPT_VIRTUALENV//_VIRTUALENV_/${VENV}}"
    fi

    if [[ -n "$CONDA_DEFAULT_ENV" ]]; then
      VENV=$(basename "${CONDA_DEFAULT_ENV}")
      NEW_PROMPT="$NEW_PROMPT${GIT_PROMPT_VIRTUALENV//_VIRTUALENV_/${VENV}}"
    fi

    NEW_PROMPT="$NEW_PROMPT$PROMPT_START$($prompt_callback)$STATUS$PROMPT_END"
  else
    NEW_PROMPT="$EMPTY_PROMPT"
  fi

  PS1="${NEW_PROMPT//_LAST_COMMAND_INDICATOR_/${LAST_COMMAND_INDICATOR}}"
}

function prompt_callback_default {
    return
}

function gp_install_prompt {
  if [ "`type -t prompt_callback`" = 'function' ]; then
      prompt_callback="prompt_callback"
  else
      prompt_callback="prompt_callback_default"
  fi
  
  if [ -z "$OLD_GITPROMPT" ]; then
    OLD_GITPROMPT=$PS1
  fi
  
  if [ -z "$GIT_PROMPT_OLD_DIR_WAS_GIT" ]; then
    GIT_PROMPT_OLD_DIR_WAS_GIT=$(we_are_on_repo)
  fi

  if [ -z "$PROMPT_COMMAND" ]; then
    PROMPT_COMMAND=setGitPrompt
  else
    PROMPT_COMMAND=${PROMPT_COMMAND%% }; # remove trailing spaces
    PROMPT_COMMAND=${PROMPT_COMMAND%\;}; # remove trailing semi-colon

    local new_entry="setGitPrompt"
    case ";$PROMPT_COMMAND;" in
      *";$new_entry;"*)
        # echo "PROMPT_COMMAND already contains: $new_entry"
        :;;
      *)
        PROMPT_COMMAND="$PROMPT_COMMAND;$new_entry"
        # echo "PROMPT_COMMAND does not contain: $new_entry"
        ;;
    esac
  fi

  local setLastCommandStateEntry="setLastCommandState"
  case ";$PROMPT_COMMAND;" in
    *";$setLastCommandStateEntry;"*)
      # echo "PROMPT_COMMAND already contains: $setLastCommandStateEntry"
      :;;
    *)
      PROMPT_COMMAND="$setLastCommandStateEntry;$PROMPT_COMMAND"
      # echo "PROMPT_COMMAND does not contain: $setLastCommandStateEntry"
      ;;
  esac

  git_prompt_dir
  source "$__GIT_PROMPT_DIR/git-prompt-help.sh"
}

gp_install_prompt
