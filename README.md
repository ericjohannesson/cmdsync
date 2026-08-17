# cmdsync
A bash-script for making the file structure of a *destination directory* identical to the file structure of a *source directory* (without changing the source), where each destination file is the result of applying a user-specified *shell command* to the corresponding source file.

The script uses [GNU find](https://www.gnu.org/software/findutils/) for listing the path and modification-time of each file, and [GNU diff](https://www.gnu.org/software/diffutils/) for determining the least amount of changes required.

```
USAGE:
  cmdsync [<options>] <command> <path-to-source> <path-to-destination>

  COMMANDS
    Any single-quoted shell-command containing '$IN' and '$OUT'.

  OPTIONS
    --dry-run
      Destination will not be modified.

    --ignore <path-to-file>
      If file contains a list of regular expressions that can be
      interpreted by grep, any file or directory matching such an
      expression will be ignored.

  EXAMPLES
    Make the destination identical to the source:
      cmdsync 'cp $IN $OUT' path/to/directory path/to/copied_directory

    Make the destination an encrypted version of the source:
      cmdsync 'gpg -e -r some@email.com -o $OUT $IN' path/to/directory path/to/encrypted_directory

    Make the destination a decrypted version of the source:
      cmdsync 'gpg -d -o $OUT $IN' path/to/encrypted_directory path/to/directory
```
