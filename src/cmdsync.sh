#!/usr/bin/bash

#############################################################################
# CMD-SYNC                                                                  #
#                                                                           #
# A bash-script for making the file structure of a destination directory    #
# identical to the file structure of a source directory (without changing   #
# the source), where each destination file is the result of applying a      #
# user-specified shell command to the corresponding source file.            #
#                                                                           #
# The script uses GNU find for listing the path and modification-time of    #
# each file, and GNU diff for determining the least amount of changes       #
# required.                                                                 #
#                                                                           #
# Copyright (C) 2026  Eric Johannesson <eric@ericjohannesson.com>           #
#############################################################################


# global variables:
cmdsync_IGNOREFILE=""
cmdsync_DRY_RUN=0
cmdsync_CMD=""
cmdsync_SRC=""
cmdsync_DEST=""

cmdsync_print_usage () {
    echo \
"USAGE:
  cmdsync [<options>] <command> <path-to-source> <path-to-destination>

  COMMANDS
    Any single-quoted shell-command containing '\$IN' and '\$OUT'.

  OPTIONS
    --dry-run
      Destination will not be modified.

    --ignore <path-to-file>
      If file contains a list of regular expressions that can be
      interpreted by grep, any file or directory matching such an
      expression will be ignored.

  EXAMPLES
    Make the destination identical to the source:
      cmdsync 'cp \$IN \$OUT' path/to/directory path/to/copied_directory

    Make the destination an encrypted version of the source:
      cmdsync 'gpg -e -r some@email.com -o \$OUT \$IN' path/to/directory path/to/encrypted_directory

    Make the destination a decrypted version of the source:
      cmdsync 'gpg -d -o \$OUT \$IN' path/to/encrypted_directory path/to/directory"
}


cmdsync_add_quotes () {
    echo "$1" | sed 's/ \$IN / "$IN" /g' | sed 's/^\$IN /"$IN" /g' | sed 's/ \$IN$/ "$IN"/g' | sed 's/ \$OUT / "$OUT" /g' | sed 's/^\$OUT /"$OUT" /g' | sed 's/ \$OUT$/ "$OUT"/g'
}

cmdsync_remove_dirs () {
    local LINE
    if [ "$cmdsync_DRY_RUN" -eq 0 ]
    then
        while read LINE
        do
            if [ -d "$cmdsync_DEST/$LINE" ]
            then
                rm -r "$cmdsync_DEST/$LINE"
            fi
        done < "$1"
    fi
}


cmdsync_make_dirs () {
    local LINE
    if [ "$cmdsync_DRY_RUN" -eq 0 ]
    then
        while read LINE
        do
            mkdir -p "$cmdsync_DEST/$LINE"
        done < "$1"
    fi
}

cmdsync_remove_files () {
    local LINE
    if [ "$cmdsync_DRY_RUN" -eq 0 ]
    then
        while read LINE
        do
            rm "$cmdsync_DEST/$LINE"
        done < "$1"
    fi
}


cmdsync_make_files () {
    local LINE IN OUT RATIO
    local FACTOR=20
    local COUNT=1
    local EMPTY=$(printf '.%.0s' {1..20})
    local FULL=$(printf '#%.0s' {1..20})

    if [ "$cmdsync_DRY_RUN" -eq 0 ]
    then
        while read LINE
        do
            IN="$cmdsync_SRC/$LINE"
            OUT="$cmdsync_DEST/$LINE"
            RATIO=$(($COUNT*$FACTOR/$2))
            echo -ne "\rSYNCING: [${FULL:0:RATIO}${EMPTY:RATIO:FACTOR}] $COUNT/$2\033[K"
            COUNT=$(($COUNT+1))
            eval "$cmdsync_CMD"
            chmod --reference="$IN" "$OUT"
            touch "$OUT" -r "$IN"
        done < "$1"
        echo ""
    fi
}

cmdsync_display_lines(){
    sed 's/^/\t/' "$1"
}

cmdsync_number_of_lines(){
    wc -l "$1" | cut -f 1 -d ' '
}


cmdsync_parse () {

    local NUMBER_OF_ARGUMENTS=$#
    local CMD SRC DEST IGNOREFILE

    if [ $NUMBER_OF_ARGUMENTS -lt 3 ]
    then
        echo 'Missing arguments' 1>&2
        cmdsync_print_usage 1>&2
        exit 2
    fi

    if [ $NUMBER_OF_ARGUMENTS -gt 6 ]
    then
        echo 'Too many arguments' 1>&2
        cmdsync_print_usage 1>&2
        exit 2
    fi


    if [ $NUMBER_OF_ARGUMENTS -eq 3 ]
    then
        CMD=$(cmdsync_add_quotes "$1")
        SRC="$2"
        DEST="$3"
    fi

    if [ $NUMBER_OF_ARGUMENTS -eq 4 ]
    then
        CMD=$(cmdsync_add_quotes "$2")
        SRC="$3"
        DEST="$4"

        if [ "$1" = "--dry-run" ]
        then
            cmdsync_DRY_RUN=1
        else
            echo "Invalid argument: '$1'" 1>&2
            cmdsync_print_usage 1>&2
            exit 2
        fi
    fi

    if [ $NUMBER_OF_ARGUMENTS -eq 5 ]
    then
        CMD=$(cmdsync_add_quotes "$3")
        SRC="$4"
        DEST="$5"
    
        if [ "$1" = "--ignore" ]
        then
            IGNOREFILE="$2"
        else
            echo "Invalid argument: '$1'" 1>&2
            cmdsync_print_usage 1>&2
            exit 2
        fi
    fi

    if [ $NUMBER_OF_ARGUMENTS -eq 6 ]
    then
        CMD=$(cmdsync_add_quotes "$4")
        SRC="$5"
        DEST="$6"

        if [ "$1" = "--dry-run" ]
        then
            cmdsync_DRY_RUN=1
            if [ "$2" = "--ignore" ]
            then
                IGNOREFILE="$3"
            else
                echo "Invalid argument: '$2'" 1>&2
                cmdsync_print_usage 1>&2
                exit 2
            fi
        else
            if [ "$1" = "--ignore" ]
            then
                IGNOREFILE="$2"
                if [ "$3" = "--dry-run" ]
                then
                    cmdsync_DRY_RUN=1
                else
                    echo "Invalid argument: '$3'" 1>&2
                    cmdsync_print_usage 1>&2
                    exit 2
                fi
            else
                echo "Invalid argument: '$1'" 1>&2
                cmdsync_print_usage 1>&2
                exit 2
            fi
        fi
    fi

    cmdsync_CMD="$CMD"

    if [ ! -d "$SRC" ]
    then
        echo "There is no directory with path '$SRC'" 1>&2
        exit 2
    fi
    cmdsync_SRC=$(realpath "$SRC")

    if [ ! "$IGNOREFILE" = "" ]
    then
        if [ ! -f "$IGNOREFILE" ]
        then
            echo "There is no file with path '$IGNOREFILE'" 1>&2
            exit 2
        fi
        cmdsync_IGNOREFILE=$(realpath "$IGNOREFILE")
    fi

    if [ ! -d "$DEST" ]
    then
        mkdir -p "$DEST"
    fi
    cmdsync_DEST=$(realpath "$DEST")

    if [ "$cmdsync_DRY_RUN" -eq 1 ]
    then
        echo "DRY RUN (destination will not be modified)"
    fi
}


cmdsync_main () {

    local TEMP_DIR=$(mktemp -d)
    local SRC_DIRS="$TEMP_DIR/src.dirs"
    local DEST_DIRS="$TEMP_DIR/dest.dirs"
    local SRC_FILES="$TEMP_DIR/src.files"
    local DEST_FILES="$TEMP_DIR/dest.files"
    local DEST_DIRS_TO_BE_REMOVED="$TEMP_DIR/dest.dirs.to.be.removed"
    local DEST_DIRS_TO_BE_CREATED="$TEMP_DIR/dest.dirs.to.be.created"
    local DEST_FILES_TO_BE_REMOVED="$TEMP_DIR/dest.files.to.be.removed"
    local DEST_FILES_TO_BE_CREATED="$TEMP_DIR/dest.files.to.be.created"
    local DEST_FILES_TO_BE_REALLY_REMOVED="$TEMP_DIR/dest.files.to.be.really.removed"
    local DEST_FILES_TO_BE_REALLY_CREATED="$TEMP_DIR/dest.files.to.be.really.created"
    local DEST_FILES_TO_BE_MODIFIED="$TEMP_DIR/dest.files.to.be.modified"
    local NR_OF_FILES_TO_BE_CREATED

    local FORMAT="%P\t%T@\n"

    if [ "$cmdsync_IGNOREFILE" = "" ]
    then
        find "$cmdsync_SRC" -type d -printf "%P\n"  | sort > "$SRC_DIRS"
        find "$cmdsync_DEST" -type d -printf "%P\n" | sort > "$DEST_DIRS"
    else
        find "$cmdsync_SRC" -type d -printf "%P\n"  | grep -f "$cmdsync_IGNOREFILE" -v | sort > "$SRC_DIRS"
        find "$cmdsync_DEST" -type d -printf "%P\n" | grep -f "$cmdsync_IGNOREFILE" -v | sort > "$DEST_DIRS"
    fi

    diff "$SRC_DIRS" "$DEST_DIRS" | grep '^>' | cut -b 3- > "$DEST_DIRS_TO_BE_REMOVED"
    diff "$SRC_DIRS" "$DEST_DIRS" | grep '^<' | cut -b 3- > "$DEST_DIRS_TO_BE_CREATED"

    echo "DIRECTORIES REMOVED: $(cmdsync_number_of_lines "$DEST_DIRS_TO_BE_REMOVED")"
    cmdsync_display_lines "$DEST_DIRS_TO_BE_REMOVED"
    cmdsync_remove_dirs "$DEST_DIRS_TO_BE_REMOVED"

    echo "DIRECTORIES CREATED: $(cmdsync_number_of_lines "$DEST_DIRS_TO_BE_CREATED")"
    cmdsync_display_lines "$DEST_DIRS_TO_BE_CREATED"
    cmdsync_make_dirs "$DEST_DIRS_TO_BE_CREATED"


    if [ "$cmdsync_IGNOREFILE" = "" ]
    then
        find "$cmdsync_SRC" -type f -printf "$FORMAT"  | sort > "$SRC_FILES"
        find "$cmdsync_DEST" -type f -printf "$FORMAT" | sort > "$DEST_FILES"
    else
        find "$cmdsync_SRC" -type f -printf "$FORMAT"  | grep -f "$cmdsync_IGNOREFILE" -v | sort > "$SRC_FILES"
        find "$cmdsync_DEST" -type f -printf "$FORMAT" | grep -f "$cmdsync_IGNOREFILE" -v | sort > "$DEST_FILES"
    fi


    diff "$SRC_FILES" "$DEST_FILES" | grep '^>' | cut -b 3- | cut -f 1 > "$DEST_FILES_TO_BE_REMOVED"
    diff "$SRC_FILES" "$DEST_FILES" | grep '^<' | cut -b 3- | cut -f 1 > "$DEST_FILES_TO_BE_CREATED"

    diff "$DEST_FILES_TO_BE_CREATED" "$DEST_FILES_TO_BE_REMOVED" | grep '^>' | cut -b 3- | cut -f 1 > "$DEST_FILES_TO_BE_REALLY_REMOVED"
    diff "$DEST_FILES_TO_BE_CREATED" "$DEST_FILES_TO_BE_REMOVED" | grep '^<' | cut -b 3- | cut -f 1 > "$DEST_FILES_TO_BE_REALLY_CREATED"
    diff "$DEST_FILES_TO_BE_CREATED" "$DEST_FILES_TO_BE_REALLY_CREATED" | grep '^<' | cut -b 3- | cut -f 1 > "$DEST_FILES_TO_BE_MODIFIED"

    echo "FILES REMOVED: $(cmdsync_number_of_lines "$DEST_FILES_TO_BE_REALLY_REMOVED")"
    cmdsync_display_lines "$DEST_FILES_TO_BE_REALLY_REMOVED"

    echo "FILES CREATED: $(cmdsync_number_of_lines "$DEST_FILES_TO_BE_REALLY_CREATED")"
    cmdsync_display_lines "$DEST_FILES_TO_BE_REALLY_CREATED"

    echo "FILES MODIFIED: $(cmdsync_number_of_lines "$DEST_FILES_TO_BE_MODIFIED")"
    cmdsync_display_lines "$DEST_FILES_TO_BE_MODIFIED"

    cmdsync_remove_files "$DEST_FILES_TO_BE_REMOVED"

    NR_OF_FILES_TO_BE_CREATED="$(cmdsync_number_of_lines "$DEST_FILES_TO_BE_CREATED")"

    if [ $NR_OF_FILES_TO_BE_CREATED -gt 0 ]
    then
        cmdsync_make_files "$DEST_FILES_TO_BE_CREATED" "$NR_OF_FILES_TO_BE_CREATED"
    fi

    rm -r "$TEMP_DIR"

}


set -e # Abort if something fails

# Parse command-line arguments and set global variables:
cmdsync_parse "$@"

echo "COMMAND: '$cmdsync_CMD'"
echo "SOURCE: $cmdsync_SRC"
echo "DESTINATION: $cmdsync_DEST"

# Start syncing:
cmdsync_main
