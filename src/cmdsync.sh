#!/usr/bin/bash

############################################################################
# cmdsync                                                                  #
#                                                                          #
# A bash-script for making the file structure of a destination directory   #
# identical to the file structure of a source directory (without changing  #
# the source), where each destination file is the result of applying a     #
# user-specified shell-command to the corresponding source file.           #
#                                                                          #
# The script uses GNU find for listing the path and modification-time of   #
# each file, and GNU diff for determining the least amount of changes      #
# required.                                                                #
#                                                                          #
# Copyright (C) 2026 Eric Johannesson <eric@ericjohannesson.com>           #
############################################################################

# Abort if something fails:
set -e

# Global variables:
cmdsync_IGNOREFILE=""
cmdsync_DRYRUN="false"
cmdsync_CMD=""
cmdsync_SRC=""
cmdsync_DEST=""
cmdsync_BACKUP=""
cmdsync_SUFFIX=$(date --universal +'.%Y.%m.%d-%H.%M.%S-UTC')


cmdsync_print_version () {
  echo "cmdsync version 3"
}

cmdsync_print_usage () {
  echo \
"USAGE:
  cmdsync [OPTIONS] --cmd COMMAND --src DIR --dest DIR
  cmdsync --help
  cmdsync --version

  COMMAND
    A single-quoted shell-command containing '\$IN' and '\$OUT'.

  OPTIONS
    --dry-run
      Destination will not be modified.

    --ignore FILE
      If FILE contains a list of regular expressions that can be
      interpreted by grep, any file or directory matching such an
      expression will be ignored.

    --backup DIR
      Save removed and modified files and directories in DIR,
      suffixed with current universal time (unless otherwise
      specified, see below).

    --suffix STRING
      Append STRING to the names of backed up files and directories.

EXAMPLES:
  # Make the destination identical to the source:
    cmdsync \\
      --cmd 'cp \$IN \$OUT' \\
      --src path/to/directory \\
      --dest path/to/copied_directory

  # Make the destination an encrypted version of the source:
    cmdsync \\
      --cmd 'gpg -e -r some@email.com -o \$OUT \$IN' \\
      --src path/to/directory \\
      --dest path/to/encrypted_directory

  # Make the destination a decrypted version of the source:
    cmdsync \\
      --cmd 'gpg -d -o \$OUT \$IN' \\
      --src path/to/encrypted_directory \\
      --dest path/to/directory"
}


cmdsync_quote () {
  echo "$1" \
    | sed 's/ \$IN / "$IN" /g' \
    | sed 's/^\$IN /"$IN" /g' \
    | sed 's/ \$IN$/ "$IN"/g' \
    | sed 's/ \$OUT / "$OUT" /g' \
    | sed 's/^\$OUT /"$OUT" /g' \
    | sed 's/ \$OUT$/ "$OUT"/g'
}

cmdsync_remove_dirs () {
  local LINE
  if [ "$cmdsync_DRYRUN" = "false" ]; then
    while read LINE; do
      rm -rf "$cmdsync_DEST/$LINE"
    done < "$1"
  fi
}

cmdsync_move_dirs () {
  local LINE
  if [ "$cmdsync_DRYRUN" = "false" ]; then
    while read LINE; do
      mkdir -p "$cmdsync_BACKUP/$LINE$cmdsync_SUFFIX"
      mv "$cmdsync_DEST/$LINE"/* "$cmdsync_BACKUP/$LINE$cmdsync_SUFFIX"/
      rmdir "$cmdsync_DEST/$LINE"
    done < "$1"
  fi
}


cmdsync_make_dirs () {
  local LINE
  if [ "$cmdsync_DRYRUN" = "false" ]; then
    while read LINE; do
      mkdir -p "$cmdsync_DEST/$LINE"
    done < "$1"
  fi
}

cmdsync_remove_files () {
  local LINE
  if [ "$cmdsync_DRYRUN" = "false" ]; then
    while read LINE; do
      rm "$cmdsync_DEST/$LINE"
    done < "$1"
  fi
}

cmdsync_move_files () {
  local LINE
  if [ "$cmdsync_DRYRUN" = "false" ]; then
    while read LINE; do
      mkdir -p "$(dirname "$cmdsync_BACKUP/$LINE")"
      mv "$cmdsync_DEST/$LINE" "$cmdsync_BACKUP/$LINE$cmdsync_SUFFIX"
    done < "$1"
  fi
}

cmdsync_make_files () {
  local LINE IN OUT RATIO
  local FACTOR=20
  local COUNT=1
  local EMPTY=$(printf '.%.0s' {1..20})
  local FULL=$(printf '#%.0s' {1..20})

  if [ "$cmdsync_DRYRUN" = "false" ]; then
    while read LINE; do
      IN="$cmdsync_SRC/$LINE"
      OUT="$cmdsync_DEST/$LINE"
      RATIO=$(($COUNT*$FACTOR/$2))
      echo -ne \
        "\r  applying command [${FULL:0:RATIO}${EMPTY:RATIO:FACTOR}] $COUNT/$2\033[K"
      COUNT=$(($COUNT+1))
      eval "$cmdsync_CMD"
      chmod --reference="$IN" "$OUT"
      touch "$OUT" -r "$IN"
    done < "$1"
    echo ""
  fi
}

cmdsync_display_lines(){
  sed 's/^/  /' "$1"
}

cmdsync_nr_of_lines(){
  wc -l "$1" \
    | cut -f 1 -d ' '
}


cmdsync_parse () {
  local CMD=""
  local SRC=""
  local DEST=""
  local IGNOREFILE=""
  while [ "$#" -gt 0 ]; do
    case "$1" in

      '--cmd')
        CMD="$2"
        if [ "$CMD" = "" ]; then
          echo "Error: --cmd requires an argument" 1>&2
          exit 1
        fi
        shift
        shift
        ;;

      '--src')
        SRC="$2"
        if [ "$SRC" = "" ]; then
          echo "Error: --src requires an argument" 1>&2
          exit 1
        fi
        shift
        shift
         ;;

      '--dest')
        DEST="$2"
        if [ "$DEST" = "" ]; then
          echo "Error: --dest requires an argument" 1>&2
          exit 1
        fi
        shift
        shift
        ;;

      '--ignore')
        IGNOREFILE="$2"
        if [ "$IGNOREFILE" = "" ]; then
          echo "Error: --ignore requires an argument" 1>&2
          exit 1
        fi
        shift
        shift
        ;;

      '--dry-run')
        cmdsync_DRYRUN="true"
        shift
        ;;

      '--backup')
        BACKUP="$2"
        if [ "$BACKUP" = "" ]; then
          echo "Error: --backup requires an argument" 1>&2
          exit 1
        fi
        shift
        shift
        ;;

      '--suffix')
        cmdsync_SUFFIX="$2"
        shift
        shift
        ;;

      '--help')
        cmdsync_print_usage
        exit 0
        ;;

      '--version')
        cmdsync_print_version
        exit 0
        ;;

      *)
        echo "Error: No such option: '$1'" 1>&2
        exit 1
        ;;
    esac
  done

  if [ "$CMD" = "" ]; then
    echo "Error: No command specified" 1>&2
    exit 1
  fi
  echo "--cmd '$CMD'"
  cmdsync_CMD=$(cmdsync_quote "$CMD")

  if [ "$SRC" = "" ]; then
    echo "Error: No source directory specified" 1>&2
    exit 1
  fi

  if [ ! -d "$SRC" ]; then
    echo "Error: No such directory: '$SRC'" 1>&2
    exit 1
  fi
  echo "--src $SRC"
  cmdsync_SRC=$(realpath "$SRC")

  if [ "$DEST" = "" ]; then
    echo "Error: No destination directory specified" 1>&2
    exit 1
  fi
  echo "--dest $DEST"
  mkdir -p "$DEST"
  cmdsync_DEST=$(realpath "$DEST")

  if [ ! "$BACKUP" = "" ]; then
    echo "--backup $BACKUP"
    mkdir -p "$BACKUP"
    cmdsync_BACKUP=$(realpath "$BACKUP")
    if [ ! "$cmdsync_SUFFIX" = "" ]; then
      echo "--suffix $cmdsync_SUFFIX"
    fi
  fi

  if [ ! "$IGNOREFILE" = "" ]; then
    if [ -f "$IGNOREFILE" ]; then
      echo "--ignore $IGNOREFILE"
      cmdsync_IGNOREFILE=$(realpath "$IGNOREFILE")
    else
      echo "Error: No such file: '$IGNOREFILE'" 1>&2
      exit 1
    fi
  fi

  if [ "$cmdsync_DRYRUN" = "true" ]; then
    echo "--dry-run (destination will not be modified)"
  fi
}

cmdsync_destfiles_in_dirs () {
  local LINE
  while read LINE; do
    find "$cmdsync_DEST/$LINE" -maxdepth 1 -type f -printf "$LINE/%P\n" \
      | sort >> "$2"
  done < "$1"
}


cmdsync_main () {
  local TEMP_DIR=$(mktemp -d)
  local SRC_DIRS="$TEMP_DIR/src.dirs"
  local DEST_DIRS="$TEMP_DIR/dest.dirs"
  local SRC_FILES="$TEMP_DIR/src.files"
  local DEST_FILES="$TEMP_DIR/dest.files"
  local DEST_DIRS_REMOVED="$TEMP_DIR/dest.dirs.removed"
  local DEST_DIRS_CREATED="$TEMP_DIR/dest.dirs.created"
  local DEST_FILES_REMOVED="$TEMP_DIR/dest.files.removed"
  local DEST_FILES_CREATED="$TEMP_DIR/dest.files.created"
  local DEST_FILES_REMOVED_NOMOD="$TEMP_DIR/dest.files.removed.nomod"
  local DEST_FILES_CREATED_NOMOD="$TEMP_DIR/dest.files.created.nomod"
  local DEST_FILES_MODIFIED="$TEMP_DIR/dest.files.modified"
  local DEST_DIRFILES_REMOVED="$TEMP_DIR/dest.dirfiles.removed"
  local NR_OF_DIRFILES_REMOVED=0
  local NR_OF_FILES_REMOVED_NOMOD=0
  local NR_OF_FILES_CREATED=0
  local NR_OF_FILES_REMOVED=0
  local NR_OF_FILES_MODIFIED=0
  local FORMAT="%P\t%T@\n"

  ###################################################################
  echo -n "Listing directories... "
  if [ "$cmdsync_IGNOREFILE" = "" ]; then
    find "$cmdsync_SRC" -type d -printf "%P\n" \
      | sort > "$SRC_DIRS"
    find "$cmdsync_DEST" -type d -printf "%P\n" \
      | sort > "$DEST_DIRS"
  else
    find "$cmdsync_SRC" -type d -printf "%P\n"  \
      | grep -f "$cmdsync_IGNOREFILE" -v \
      | sort > "$SRC_DIRS"
    find "$cmdsync_DEST" -type d -printf "%P\n" \
      | grep -f "$cmdsync_IGNOREFILE" -v \
      | sort > "$DEST_DIRS"
  fi

  diff "$SRC_DIRS" "$DEST_DIRS" \
    | grep '^>' \
    | cut -b 3- > "$DEST_DIRS_REMOVED"
  diff "$SRC_DIRS" "$DEST_DIRS" \
    | grep '^<' \
    | cut -b 3- > "$DEST_DIRS_CREATED"

  echo "Done."
  echo "DIRECTORIES TO BE REMOVED ($(cmdsync_nr_of_lines $DEST_DIRS_REMOVED))"
  cmdsync_display_lines "$DEST_DIRS_REMOVED"
  echo "DIRECTORIES TO BE CREATED ($(cmdsync_nr_of_lines $DEST_DIRS_CREATED))"
  cmdsync_display_lines "$DEST_DIRS_CREATED"

  # Listing files in removed directories
  touch "$DEST_DIRFILES_REMOVED"
  cmdsync_destfiles_in_dirs "$DEST_DIRS_REMOVED" "$DEST_DIRFILES_REMOVED"

  ###################################################################
  echo -n "Syncing directories... "
  if [ "$cmdsync_BACKUP" = "" ]; then
    cmdsync_remove_dirs "$DEST_DIRS_REMOVED"
  else
    cmdsync_move_dirs "$DEST_DIRS_REMOVED"
  fi
  cmdsync_make_dirs "$DEST_DIRS_CREATED"
  echo "Done."

  ###################################################################
  echo -n "Listing files... "
  if [ "$cmdsync_IGNOREFILE" = "" ]; then
    find "$cmdsync_SRC" -type f -printf "$FORMAT" \
      | sort > "$SRC_FILES"
    find "$cmdsync_DEST" -type f -printf "$FORMAT" \
      | sort > "$DEST_FILES"
  else
    find "$cmdsync_SRC" -type f -printf "$FORMAT" \
      | grep -f "$cmdsync_IGNOREFILE" -v \
      | sort > "$SRC_FILES"
    find "$cmdsync_DEST" -type f -printf "$FORMAT" \
      | grep -f "$cmdsync_IGNOREFILE" -v \
      | sort > "$DEST_FILES"
  fi

  diff "$SRC_FILES" "$DEST_FILES" \
    | grep '^>' \
    | cut -b 3- \
    | cut -f 1 > "$DEST_FILES_REMOVED"

  diff "$SRC_FILES" "$DEST_FILES" \
    | grep '^<' \
    | cut -b 3- \
    | cut -f 1 > "$DEST_FILES_CREATED"

  diff "$DEST_FILES_CREATED" "$DEST_FILES_REMOVED" \
    | grep '^>' \
    | cut -b 3- \
    | cut -f 1 > "$DEST_FILES_REMOVED_NOMOD"

  diff "$DEST_FILES_CREATED" "$DEST_FILES_REMOVED" \
    | grep '^<' \
    | cut -b 3- \
    | cut -f 1 > "$DEST_FILES_CREATED_NOMOD"

  diff "$DEST_FILES_CREATED" "$DEST_FILES_CREATED_NOMOD" \
    | grep '^<' \
    | cut -b 3- \
    | cut -f 1 > "$DEST_FILES_MODIFIED"

  echo "Done."

  NR_OF_DIRFILES_REMOVED=$(cmdsync_nr_of_lines $DEST_DIRFILES_REMOVED)
  NR_OF_FILES_REMOVED_NOMOD=$(cmdsync_nr_of_lines $DEST_FILES_REMOVED_NOMOD)
  NR_OF_FILES_REMOVED=$(( $NR_OF_FILES_REMOVED_NOMOD + $NR_OF_DIRFILES_REMOVED ))
  echo "FILES TO BE REMOVED ($NR_OF_FILES_REMOVED)"
  cmdsync_display_lines "$DEST_FILES_REMOVED_NOMOD"
  cmdsync_display_lines "$DEST_DIRFILES_REMOVED"

  echo "FILES TO BE CREATED ($(cmdsync_nr_of_lines $DEST_FILES_CREATED_NOMOD))"
  cmdsync_display_lines "$DEST_FILES_CREATED_NOMOD"

  echo "FILES TO BE MODIFIED ($(cmdsync_nr_of_lines $DEST_FILES_MODIFIED))"
  cmdsync_display_lines "$DEST_FILES_MODIFIED"


  ###################################################################
  echo "Syncing files..."
  if [ "$cmdsync_BACKUP" = "" ]; then
    cmdsync_remove_files "$DEST_FILES_REMOVED"
  else
    cmdsync_move_files "$DEST_FILES_REMOVED"
  fi

  NR_OF_FILES_CREATED=$(cmdsync_nr_of_lines "$DEST_FILES_CREATED")
  if [ "$NR_OF_FILES_CREATED" -gt 0 ]; then
    cmdsync_make_files "$DEST_FILES_CREATED" "$NR_OF_FILES_CREATED"
  fi
  echo "Done."

  ###################################################################
  rm -r "$TEMP_DIR"
}


if [ "$#" -gt 0 ]; then
  # Parse command-line arguments and set global variables:
  cmdsync_parse "$@"
  # Start syncing:
  cmdsync_main
else
  cmdsync_print_usage
fi

