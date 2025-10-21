# cmd-sync
A bash-script for making the file structure of a *destination directory* identical to the file structure of a *source directory* (without changing the source), where each destination file is the result of applying a user-specified *shell command* to the corresponding source file. Beware, however, that supplied with a suitable command, the script *can* do virtually *anything* (like erasing the source directory).

The script uses [GNU find](https://www.gnu.org/software/findutils/) for listing the path and modification-time of each file, and [GNU diff](https://www.gnu.org/software/diffutils/) for determining the least amount of changes required. If a file named `.cmd-sync-ignore` is present immediately inside the *source directory*, each line of which is a regular expression that can be interpreted by [GNU grep](https://www.gnu.org/software/grep/), the script will ignore files whose path matches either of these expressions.

## Usage

### General syntax

```
bash cmd-sync.sh '<shell command containing expressions '$IN' and '$OUT'>'
                  <path to source directory>
                  <path to destination directory> [ --dry-run ]
```

### Examples

Make the destination identical to the source:

```bash
bash cmd-sync.sh 'cp $IN $OUT' path/to/directory path/to/copied_directory
```

Make the destination an encrypted version of the source:

```bash
bash cmd-sync.sh 'gpg --encrypt --recipient some@email.com --output $OUT $IN' path/to/directory path/to/encrypted_directory
```

Make the destination a decrypted version of the source:

```bash
bash cmd-sync.sh 'gpg --decrypt --output $OUT $IN' path/to/encrypted_directory path/to/directory
```
