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
cmdsync_IGNORE=""
cmdsync_DRYRUN="false"
cmdsync_CMD=""
cmdsync_SRC=""
cmdsync_DEST=""
cmdsync_BACKUP=""
cmdsync_SUFFIX=$(date --universal +'.%Y.%m.%d-%H.%M.%S-UTC')
cmdsync_QUIET="false"


cmdsync_print_version () {
  echo 5
}

cmdsync_print_usage () {
  echo \
"USAGE:
  cmdsync [OPTIONS] --cmd COMMAND --src DIR --dest DIR
  cmdsync --help
  cmdsync --version

  COMMAND
    A single-quoted shell-command containing '\$IN' and '\$OUT',
    which will be evaluated for each source file with its path
    assigned to 'IN' and with the corresponding destination
    path assigned to 'OUT'.

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
      specified; see --suffix).

    --suffix STRING
      Append STRING to the names of backed up files and directories.

    --quiet
      Only report errors.

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
      --dest path/to/directory

  # Make the destination identical to the source, but keep
    removed and modified files and directories in a backup:
    cmdsync \\
      --cmd 'cp \$IN \$OUT' \\
      --src path/to/directory \\
      --dest path/to/copied_directory \\
      --backup path/to/backup"
}

cmdsync_report () {
  if [ "$cmdsync_QUIET" = "false" ]; then
    echo "$1"
  fi
}

cmdsync_report_error () {
  echo "cmdsync error:" "$1" 1>&2
}


cmdsync_quote () {
  # to ensure correct handling of paths with spaces
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
  # move dirs to backup instead of just deleting them
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
  # move files to backup instead of just deleting them
  local LINE
  if [ "$cmdsync_DRYRUN" = "false" ]; then
    while read LINE; do
      mkdir -p "$(dirname "$cmdsync_BACKUP/$LINE")"
      mv "$cmdsync_DEST/$LINE" "$cmdsync_BACKUP/$LINE$cmdsync_SUFFIX"
    done < "$1"
  fi
}

cmdsync_make_files () {
  # evaluate shell-command with respect to each source and destination file
  if [ "$2" -gt 0 ]; then
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
  fi
}

cmdsync_make_files_quiet () {
  # evaluate shell-command with respect to each source and destination file
  if [ "$2" -gt 0 ]; then
    local LINE IN OUT
    if [ "$cmdsync_DRYRUN" = "false" ]; then
      while read LINE; do
        IN="$cmdsync_SRC/$LINE"
        OUT="$cmdsync_DEST/$LINE"
        eval "$cmdsync_CMD"
        chmod --reference="$IN" "$OUT"
        touch "$OUT" -r "$IN"
      done < "$1"
    fi
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
# parse command line arguments and set global variables
  local CMD
  local SRC
  local DEST
  local IGNORE
  local BACKUP
  while [ "$#" -gt 0 ]; do
    case "$1" in

      '--cmd')
        if [ "$2" ]; then
          CMD="$2"
        else
          cmdsync_report_error "--cmd requires an argument"
          exit 1
        fi
        shift
        shift
        ;;

      '--src')
        if [ "$2" ]; then
          SRC="$2"
        else
          cmdsync_report_error "--src requires an argument"
          exit 1
        fi
        shift
        shift
         ;;

      '--dest')
        if [ "$2" ]; then
          DEST="$2"
        else
          cmdsync_report_error "--dest requires an argument"
          exit 1
        fi
        shift
        shift
        ;;

      '--ignore')
        if [ "$2" ]; then
          IGNORE="$2"
        else
          cmdsync_report_error "--ignore requires an argument"
          exit 1
        fi
        shift
        shift
        ;;

      '--dry-run')
        cmdsync_DRYRUN="true"
        shift
        ;;

      '--quiet')
        cmdsync_QUIET="true"
        shift
        ;;

      '--backup')
        if [ "$2" ]; then
          BACKUP="$2"
        else
          cmdsync_report_error "--backup requires an argument"
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
        cmdsync_report_error "no such option: '$1'"
        exit 1
        ;;
    esac
  done

  cmdsync_report "--cmd '$CMD'"
  cmdsync_CMD=$(cmdsync_quote "$CMD")

  if [ ! "$SRC" ]; then
    cmdsync_report_error "no source directory specified"
    exit 1
  fi
  if [ ! -d "$SRC" ]; then
    cmdsync_report_error "no such directory: '$SRC'"
    exit 1
  fi
  cmdsync_report "--src $SRC"
  cmdsync_SRC=$(realpath "$SRC")

  if [ ! "$DEST" ]; then
    cmdsync_report_error "no destination directory specified"
    exit 1
  fi
  cmdsync_report "--dest $DEST"
  mkdir -p "$DEST"
  cmdsync_DEST=$(realpath "$DEST")

  if [ "$BACKUP" ]; then
    cmdsync_report "--backup $BACKUP"
    mkdir -p "$BACKUP"
    cmdsync_BACKUP=$(realpath "$BACKUP")
    cmdsync_report "--suffix '$cmdsync_SUFFIX'"
  fi

  if [ "$IGNORE" ]; then
    if [ -f "$IGNORE" ]; then
      cmdsync_report "--ignore $IGNORE"
      cmdsync_IGNORE=$(realpath "$IGNORE")
    else
      cmdsync_report_error "no such file: '$IGNORE'"
      exit 1
    fi
  fi

  if [ "$cmdsync_DRYRUN" = "true" ]; then
    cmdsync_report "--dry-run (destination will not be modified)"
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
  cmdsync_report "Comparing directories... "
  if [ "$cmdsync_IGNORE" = "" ]; then
    find "$cmdsync_SRC" -type d -printf "%P\n" \
      | sort > "$SRC_DIRS"
    find "$cmdsync_DEST" -type d -printf "%P\n" \
      | sort > "$DEST_DIRS"
  else
    find "$cmdsync_SRC" -type d -printf "%P\n"  \
      | grep -f "$cmdsync_IGNORE" -v \
      | sort > "$SRC_DIRS"
    find "$cmdsync_DEST" -type d -printf "%P\n" \
      | grep -f "$cmdsync_IGNORE" -v \
      | sort > "$DEST_DIRS"
  fi

  diff "$SRC_DIRS" "$DEST_DIRS" \
    | grep '^>' \
    | cut -b 3- > "$DEST_DIRS_REMOVED"
  diff "$SRC_DIRS" "$DEST_DIRS" \
    | grep '^<' \
    | cut -b 3- > "$DEST_DIRS_CREATED"
  cmdsync_report "Done."

  if [ "$cmdsync_QUIET" = "false" ]; then
    echo "DIRECTORIES TO BE REMOVED ($(cmdsync_nr_of_lines $DEST_DIRS_REMOVED))"
    cmdsync_display_lines "$DEST_DIRS_REMOVED"
    echo "DIRECTORIES TO BE CREATED ($(cmdsync_nr_of_lines $DEST_DIRS_CREATED))"
    cmdsync_display_lines "$DEST_DIRS_CREATED"
  fi

  # Listing files in removed directories
  touch "$DEST_DIRFILES_REMOVED"
  cmdsync_destfiles_in_dirs "$DEST_DIRS_REMOVED" "$DEST_DIRFILES_REMOVED"

  ###################################################################
  cmdsync_report "Syncing directories... "
  if [ "$cmdsync_BACKUP" = "" ]; then
    cmdsync_remove_dirs "$DEST_DIRS_REMOVED"
  else
    cmdsync_move_dirs "$DEST_DIRS_REMOVED"
  fi
  cmdsync_make_dirs "$DEST_DIRS_CREATED"
  cmdsync_report "Done."

  ###################################################################
  cmdsync_report "Comparing files... "
  if [ "$cmdsync_IGNORE" = "" ]; then
    find "$cmdsync_SRC" -type f -printf "$FORMAT" \
      | sort > "$SRC_FILES"
    find "$cmdsync_DEST" -type f -printf "$FORMAT" \
      | sort > "$DEST_FILES"
  else
    find "$cmdsync_SRC" -type f -printf "$FORMAT" \
      | grep -f "$cmdsync_IGNORE" -v \
      | sort > "$SRC_FILES"
    find "$cmdsync_DEST" -type f -printf "$FORMAT" \
      | grep -f "$cmdsync_IGNORE" -v \
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
  cmdsync_report "Done."

  if [ "$cmdsync_QUIET" = "false" ]; then
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
  fi

  ###################################################################
  cmdsync_report "Syncing files..."
  if [ "$cmdsync_BACKUP" = "" ]; then
    cmdsync_remove_files "$DEST_FILES_REMOVED"
  else
    cmdsync_move_files "$DEST_FILES_REMOVED"
  fi

  NR_OF_FILES_CREATED=$(cmdsync_nr_of_lines "$DEST_FILES_CREATED")
  if [ "$cmdsync_QUIET" = "false" ]; then
    cmdsync_make_files "$DEST_FILES_CREATED" "$NR_OF_FILES_CREATED"
  else
    cmdsync_make_files_quiet "$DEST_FILES_CREATED" "$NR_OF_FILES_CREATED"
  fi
  cmdsync_report "Done."

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

