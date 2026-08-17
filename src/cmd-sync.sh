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
cmd_sync_IGNOREFILE=""
cmd_sync_DRY_RUN=0
cmd_sync_CMD=""
cmd_sync_SRC=""
cmd_sync_DEST=""

cmd_sync_print_usage () {
    echo "USAGE:"
    echo ""
    echo "  cmd-sync [<options>] <command> <path-to-source> <path-to-destination>"
    echo ""
    echo "  COMMANDS:"
    echo ""
    echo "    Any single-quoted shell-command containing '\$IN' and '\$OUT'."
    echo ""
    echo "  OPTIONS:"
    echo ""
    echo "    --dry-run"
    echo ""
    echo "        Destination will not be modified."
    echo ""
    echo "    --ignore <path-to-file>"
    echo ""
    echo "        If file contains a list of regular expressions that can be"
    echo "        interpreted by grep, any file or directory matching such an"
    echo "        expression will be ignored."
    echo ""
    echo "  EXAMPLES:"
    echo ""
    echo "  - Make the destination identical to the source:"
    echo ""
    echo "    cmd-sync 'cp \$IN \$OUT' path/to/directory path/to/copied_directory"
    echo ""
    echo "  - Make the destination an encrypted version of the source:"
    echo ""
    echo "    cmd-sync 'gpg -e -r some@email.com -o \$OUT \$IN' path/to/directory path/to/encrypted_directory"
    echo ""
    echo "  - Make the destination a decrypted version of the source:"
    echo ""
    echo "    cmd-sync 'gpg -d -o \$OUT \$IN' path/to/encrypted_directory path/to/directory"
}

cmd_sync_add_quotes () {
    echo "$1" | sed 's/ \$IN / "$IN" /g' | sed 's/^\$IN /"$IN" /g' | sed 's/ \$IN$/ "$IN"/g' | sed 's/ \$OUT / "$OUT" /g' | sed 's/^\$OUT /"$OUT" /g' | sed 's/ \$OUT$/ "$OUT"/g'
}

cmd_sync_remove_dirs () {
    local LINE
    if [ "$cmd_sync_DRY_RUN" -eq 0 ]
    then
        while read LINE
        do
            if [ -d "$cmd_sync_DEST/$LINE" ]
            then
                rm -r "$cmd_sync_DEST/$LINE"
            fi
        done < "$1"
    fi
}


cmd_sync_make_dirs () {
    local LINE
    if [ "$cmd_sync_DRY_RUN" -eq 0 ]
    then
        while read LINE
        do
            mkdir -p "$cmd_sync_DEST/$LINE"
        done < "$1"
    fi
}

cmd_sync_remove_files () {
    local LINE
    if [ "$cmd_sync_DRY_RUN" -eq 0 ]
    then
        while read LINE
        do
            rm "$cmd_sync_DEST/$LINE"
        done < "$1"
    fi
}


cmd_sync_make_files () {
    local LINE IN OUT RATIO
    local FACTOR=20
    local COUNT=1
    local EMPTY=$(printf '.%.0s' {1..20})
    local FULL=$(printf '#%.0s' {1..20})

    if [ "$cmd_sync_DRY_RUN" -eq 0 ]
    then
        while read LINE
        do
            IN="$cmd_sync_SRC/$LINE"
            OUT="$cmd_sync_DEST/$LINE"
            RATIO=$(($COUNT*$FACTOR/$2))
            echo -ne "\rSYNCING: [${FULL:0:RATIO}${EMPTY:RATIO:FACTOR}] $COUNT/$2\033[K"
            COUNT=$(($COUNT+1))
            eval "$cmd_sync_CMD"
            touch "$OUT" -r "$IN"
        done < "$1"
        echo ""
    fi
}

cmd_sync_display_lines(){
    sed 's/^/\t/' "$1"
}

cmd_sync_number_of_lines(){
    wc -l "$1" | cut -f 1 -d ' '
}


cmd_sync_parse () {

    local NUMBER_OF_ARGUMENTS=$#
    local DEST

    if [ $NUMBER_OF_ARGUMENTS -lt 3 ]
    then
        cmd_sync_print_usage
        exit 2
    fi

    if [ $NUMBER_OF_ARGUMENTS -gt 6 ]
    then
        cmd_sync_print_usage
        exit 2
    fi


    if [ $NUMBER_OF_ARGUMENTS -eq 3 ]
    then
        cmd_sync_CMD=$(cmd_sync_add_quotes "$1")
        cmd_sync_SRC=$(realpath "$2")
        DEST="$3"
    fi

    if [ $NUMBER_OF_ARGUMENTS -eq 4 ]
    then
        cmd_sync_CMD=$(cmd_sync_add_quotes "$2")
        cmd_sync_SRC=$(realpath "$3")
        DEST="$4"

        if [ "$1" = "--dry-run" ]
        then
            cmd_sync_DRY_RUN=1
        else
            cmd_sync_print_usage
            exit 2
        fi
    fi

    if [ $NUMBER_OF_ARGUMENTS -eq 5 ]
    then
        cmd_sync_CMD=$(cmd_sync_add_quotes "$3")
        cmd_sync_SRC=$(realpath "$4")
        DEST="$5"
    
        if [ "$1" = "--ignore" ]
        then
            cmd_sync_IGNOREFILE=$(realpath "$2")
        else
            cmd_sync_print_usage
            exit 2
        fi
    fi

    if [ $NUMBER_OF_ARGUMENTS -eq 6 ]
    then
        cmd_sync_CMD=$(cmd_sync_add_quotes "$4")
        cmd_sync_SRC=$(realpath "$5")
        DEST="$6"

        if [ "$1" = "--dry-run" ]
        then
            cmd_sync_DRY_RUN=1

            if [ "$2" = "--ignore" ]
            then
                cmd_sync_IGNOREFILE=$(realpath "$3")
            else
                cmd_sync_print_usage
                exit 2
            fi
        fi

        if [ "$1" = "--ignore" ]
        then
            cmd_sync_IGNOREFILE=$(realpath "$2")
        
            if [ "$2" = "--dry-run" ]
            then
                cmd_sync_DRY_RUN=1
            else
                cmd_sync_print_usage
                exit 2
            fi
        fi
    fi

    if [ ! -d "$cmd_sync_SRC" ]
    then
        echo "There is no directory with path '$cmd_sync_SRC'"
        exit 2
    fi

    if [ ! "$cmd_sync_IGNOREFILE" = "" ]
    then
        if [ ! -f "$cmd_sync_IGNOREFILE" ]
        then
            echo "There is no file with path '$cmd_sync_IGNOREFILE'"
            exit 2
        fi
    fi

    if [ ! -d "$DEST" ]
    then
        mkdir -p "$DEST"
    fi

    cmd_sync_DEST=$(realpath "$DEST")

    if [ "$cmd_sync_DRY_RUN" -eq 1 ]
    then
        echo "DRY RUN (destination will not be modified)"
    fi
}


cmd_sync_main () {

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

    if [ "$cmd_sync_IGNOREFILE" = "" ]
    then
        find "$cmd_sync_SRC" -type d -printf "%P\n"  | sort > "$SRC_DIRS"
        find "$cmd_sync_DEST" -type d -printf "%P\n" | sort > "$DEST_DIRS"
    else
        find "$cmd_sync_SRC" -type d -printf "%P\n"  | grep -f "$cmd_sync_IGNOREFILE" -v | sort > "$SRC_DIRS"
        find "$cmd_sync_DEST" -type d -printf "%P\n" | grep -f "$cmd_sync_IGNOREFILE" -v | sort > "$DEST_DIRS"
    fi

    diff "$SRC_DIRS" "$DEST_DIRS" | grep '^>' | cut -b 3- > "$DEST_DIRS_TO_BE_REMOVED"
    diff "$SRC_DIRS" "$DEST_DIRS" | grep '^<' | cut -b 3- > "$DEST_DIRS_TO_BE_CREATED"

    echo "DIRECTORIES TO BE REMOVED: $(cmd_sync_number_of_lines "$DEST_DIRS_TO_BE_REMOVED")"
    cmd_sync_display_lines "$DEST_DIRS_TO_BE_REMOVED"
    cmd_sync_remove_dirs "$DEST_DIRS_TO_BE_REMOVED"

    echo "DIRECTORIES TO BE CREATED: $(cmd_sync_number_of_lines "$DEST_DIRS_TO_BE_CREATED")"
    cmd_sync_display_lines "$DEST_DIRS_TO_BE_CREATED"
    cmd_sync_make_dirs "$DEST_DIRS_TO_BE_CREATED"


    if [ "$cmd_sync_IGNOREFILE" = "" ]
    then
        find "$cmd_sync_SRC" -type f -printf "$FORMAT"  | sort > "$SRC_FILES"
        find "$cmd_sync_DEST" -type f -printf "$FORMAT" | sort > "$DEST_FILES"
    else
        find "$cmd_sync_SRC" -type f -printf "$FORMAT"  | grep -f "$cmd_sync_IGNOREFILE" -v | sort > "$SRC_FILES"
        find "$cmd_sync_DEST" -type f -printf "$FORMAT" | grep -f "$cmd_sync_IGNOREFILE" -v | sort > "$DEST_FILES"
    fi


    diff "$SRC_FILES" "$DEST_FILES" | grep '^>' | cut -b 3- | cut -f 1 > "$DEST_FILES_TO_BE_REMOVED"
    diff "$SRC_FILES" "$DEST_FILES" | grep '^<' | cut -b 3- | cut -f 1 > "$DEST_FILES_TO_BE_CREATED"

    diff "$DEST_FILES_TO_BE_CREATED" "$DEST_FILES_TO_BE_REMOVED" | grep '^>' | cut -b 3- | cut -f 1 > "$DEST_FILES_TO_BE_REALLY_REMOVED"
    diff "$DEST_FILES_TO_BE_CREATED" "$DEST_FILES_TO_BE_REMOVED" | grep '^<' | cut -b 3- | cut -f 1 > "$DEST_FILES_TO_BE_REALLY_CREATED"
    diff "$DEST_FILES_TO_BE_CREATED" "$DEST_FILES_TO_BE_REALLY_CREATED" | grep '^<' | cut -b 3- | cut -f 1 > "$DEST_FILES_TO_BE_MODIFIED"

    echo "FILES TO BE REMOVED: $(cmd_sync_number_of_lines "$DEST_FILES_TO_BE_REALLY_REMOVED")"
    cmd_sync_display_lines "$DEST_FILES_TO_BE_REALLY_REMOVED"

    echo "FILES TO BE CREATED: $(cmd_sync_number_of_lines "$DEST_FILES_TO_BE_REALLY_CREATED")"
    cmd_sync_display_lines "$DEST_FILES_TO_BE_REALLY_CREATED"

    echo "FILES TO BE MODIFIED: $(cmd_sync_number_of_lines "$DEST_FILES_TO_BE_MODIFIED")"
    cmd_sync_display_lines "$DEST_FILES_TO_BE_MODIFIED"

    cmd_sync_remove_files "$DEST_FILES_TO_BE_REMOVED"

    NR_OF_FILES_TO_BE_CREATED="$(cmd_sync_number_of_lines "$DEST_FILES_TO_BE_CREATED")"

    if [ $NR_OF_FILES_TO_BE_CREATED -gt 0 ]
    then
        cmd_sync_make_files "$DEST_FILES_TO_BE_CREATED" "$NR_OF_FILES_TO_BE_CREATED"
    fi

    rm -r "$TEMP_DIR"

}


set -e # Abort if something fails

# Parse command-line arguments and set global variables:
cmd_sync_parse "$@"

# Start syncing:
cmd_sync_main
