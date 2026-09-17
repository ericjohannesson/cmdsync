# cmdsync
A bash-script for making the file structure of a *destination directory* identical to the file structure of a *source directory* (without changing the source), where each destination file is the result of applying a user-specified *shell command* to the corresponding source file.

The script uses [GNU find](https://www.gnu.org/software/findutils/) for listing the path and modification-time of each file, and [GNU diff](https://www.gnu.org/software/diffutils/) for determining the least amount of changes required.

```
USAGE:
  cmdsync [OPTIONS] --cmd COMMAND --src DIR --dest DIR

  COMMAND
    A single-quoted shell-command containing '$IN' and '$OUT'.

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
    cmdsync \
      --cmd 'cp $IN $OUT' \
      --src path/to/directory \
      --dest path/to/copied_directory

  # Make the destination an encrypted version of the source:
    cmdsync \
      --cmd 'gpg -e -r some@email.com -o $OUT $IN' \
      --src path/to/directory \
      --dest path/to/encrypted_directory

  # Make the destination a decrypted version of the source:
    cmdsync \
      --cmd 'gpg -d -o $OUT $IN' \
      --src path/to/encrypted_directory \
      --dest path/to/directory
```
