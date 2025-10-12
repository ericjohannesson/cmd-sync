# cmd-sync
A bash-script for making the file structure of a *destination directory* identical to the file structure of a *source directory* (without changing the source), where each destination file is the result of applying an arbitrary *shell command* to the corresponding source file. 

The script uses **GNU find** for listing the path and modification-time of each file, and **GNU diff** for determining the least amount of changes required. If a file named `.cmd-sync-ignore` is present immediately inside the *source directory*, each line of which is a regular expression that can be interpreted by **GNU grep**, the script will ignore files whose path matches either of these expressions.

## Usage

### General syntax

```
bash cmd-sync.sh '<shell command containing expressions '"$IN"' and '"$OUT"'>'
                  <path to source directory>
                  <path to destination directory> [ dry-run ]
```

### Examples

Make the destination identical to the source:

```bash
bash cmd-sync.sh 'cp "$IN" "$OUT"' path/to/directory path/to/copied_directory
```

Make the destination an encrypted version of the source:

```bash
bash cmd-sync.sh 'gpg --encrypt --recipient some@email.com --output "$OUT" "$IN"' path/to/directory path/to/encrypted_directory
```

Make the destination a decrypted version of the source:

```bash
bash cmd-sync.sh 'gpg --decrypt --output "$OUT" "$IN"' path/to/encrypted_directory path/to/directory
```
