#############################################################################
# CMD-SYNC                                                                  #
#                                                                           #
# A bash-script for making the file structure of a destination directory    #
# identical to the file structure of a source directory (without changing   #
# the source), where each destination file is the result of applying a      #
# user-specified shell command to the corresponding source file. Beware,    #
# however, that supplied with a suitable command, the script can do         #
# virtually anything (like erasing the source directory).                   #
#                                                                           #
# The script uses GNU find for listing the path and modification-time of    #
# each file, and GNU diff for determining the least amount of changes       #
# required. If a file named '.cmd-sync-ignore' is present immediately       #
# inside the source directory, each line of which is a regular expression   #
# that can be interpreted by GNU grep, the script will ignore files whose   #
# path matches either of these expressions.                                 #
#                                                                           #
# Written by Eric Johannesson, eric@ericjohannesson.com                     #
#############################################################################

set -e	# Abort if something fails

print_usage(){
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

add_quotes(){
	echo "$1" | sed 's/ \$IN / "$IN" /g' | sed 's/^\$IN /"$IN" /g' | sed 's/ \$IN$/ "$IN"/g' | sed 's/ \$OUT / "$OUT" /g' | sed 's/^\$OUT /"$OUT" /g' | sed 's/ \$OUT$/ "$OUT"/g'
}

remove_dirs(){
	if [ "$DRY_RUN" -eq 0 ]
	then
		while read LINE
		do
			if [ -d "$DEST/$LINE" ]
			then
				rm -r "$DEST/$LINE"
			fi
		done < "$1"
	fi
}


make_dirs(){
	if [ "$DRY_RUN" -eq 0 ]
	then
		while read LINE
		do
			mkdir -p "$DEST/$LINE"
		done < "$1"
	fi
}

remove_files(){
	if [ "$DRY_RUN" -eq 0 ]
	then
		while read LINE
		do
			rm "$DEST/$LINE"
		done < "$1"
	fi
}


make_files(){
	if [ "$DRY_RUN" -eq 0 ]
	then
		while read LINE
		do
			IN="$SRC/$LINE"
			OUT="$DEST/$LINE"
			eval "$CMD"
			touch "$OUT" -r "$IN"
		done < "$1"
	fi
}

display_lines(){
	sed 's/^/\t/' "$1"
}

number_of_lines(){
	wc -l "$1" | cut -f 1 -d ' '
}

# Parse command-line arguments

NUMBER_OF_ARGUMENTS=$#
IGNOREFILE=""
DRY_RUN=0

if [ $NUMBER_OF_ARGUMENTS -lt 3 ]
then
	print_usage
	exit 2
fi

if [ $NUMBER_OF_ARGUMENTS -gt 6 ]
then
	print_usage
	exit 2
fi


if [ $NUMBER_OF_ARGUMENTS -eq 3 ]
then
	CMD=$(add_quotes "$1")
	SRC=$(realpath "$2")
	DEST_="$3"
fi

if [ $NUMBER_OF_ARGUMENTS -eq 4 ]
then
	CMD=$(add_quotes "$2")
	SRC=$(realpath "$3")
	DEST_="$4"

	if [ "$1" = "--dry-run" ]
	then
		echo "DRY RUN (destination will not be modified)"
		DRY_RUN=1
	else
		print_usage
		exit 2
	fi
fi

if [ $NUMBER_OF_ARGUMENTS -eq 5 ]
then
	CMD=$(add_quotes "$3")
	SRC=$(realpath "$4")
	DEST_="$5"
	
	if [ "$1" = "--ignore" ]
	then
		IGNOREFILE=$(realpath "$2")
	else
		print_usage
		exit 2
	fi
fi



if [ $NUMBER_OF_ARGUMENTS -eq 6 ]
then
	CMD=$(add_quotes "$4")
	SRC=$(realpath "$5")
	DEST_="$6"

	if [ "$1" = "--dry-run" ]
	then
		DRY_RUN=1

		if [ "$2" = "--ignore" ]
		then
			IGNOREFILE=$(realpath "$3")
		else
			print_usage
			exit 2
		fi
	fi
	
	if [ "$1" = "--ignore" ]
	then
		IGNOREFILE=$(realpath "$2")
		
		if [ "$2" = "--dry-run" ]
		then
			DRY_RUN=1
		else
			print_usage
			exit 2
		fi
	fi
fi

if [ ! -d "$SRC" ]
then
	echo "There is no directory with path '$SRC'"
	exit 2
fi

if [ ! "$IGNOREFILE" = "" ]
then
	if [ ! -f "$IGNOREFILE" ]
	then
		echo "There is no file with path '$IGNOREFILE'"
		exit 2
	fi
fi

if [ ! -d "$DEST_" ]
then
	mkdir -p "$DEST_"
fi

DEST=$(realpath "$DEST_")

if [ "$DRY_RUN" -eq 1 ]
then
	echo "DRY RUN (destination will not be modified)"
fi

# Start syncing

TEMP_DIR=$(mktemp -d)
SRC_DIRS="$TEMP_DIR/src.dirs"
DEST_DIRS="$TEMP_DIR/dest.dirs"
SRC_FILES="$TEMP_DIR/src.files"
DEST_FILES="$TEMP_DIR/dest.files"
DEST_DIRS_TO_BE_REMOVED="$TEMP_DIR/dest.dirs.to.be.removed"
DEST_DIRS_TO_BE_CREATED="$TEMP_DIR/dest.dirs.to.be.created"
DEST_FILES_TO_BE_REMOVED="$TEMP_DIR/dest.files.to.be.removed"
DEST_FILES_TO_BE_CREATED="$TEMP_DIR/dest.files.to.be.created"

mkdir -p "$TEMP_DIR"

if [ "$IGNOREFILE" = "" ]
then
	find "$SRC" -type d -printf "%P\n"  | sort > "$SRC_DIRS"
	find "$DEST" -type d -printf "%P\n" | sort > "$DEST_DIRS"
else
	find "$SRC" -type d -printf "%P\n"  | grep -f "$IGNOREFILE" -v | sort > "$SRC_DIRS"
	find "$DEST" -type d -printf "%P\n" | grep -f "$IGNOREFILE" -v | sort > "$DEST_DIRS"
fi

diff "$SRC_DIRS" "$DEST_DIRS" | grep '^>' | cut -b 3- > "$DEST_DIRS_TO_BE_REMOVED"
diff "$SRC_DIRS" "$DEST_DIRS" | grep '^<' | cut -b 3- > "$DEST_DIRS_TO_BE_CREATED"

echo "DIRECTORIES TO BE REMOVED: $(number_of_lines "$DEST_DIRS_TO_BE_REMOVED")"
display_lines "$DEST_DIRS_TO_BE_REMOVED"
remove_dirs "$DEST_DIRS_TO_BE_REMOVED"

echo "DIRECTORIES TO BE CREATED: $(number_of_lines "$DEST_DIRS_TO_BE_CREATED")"
display_lines "$DEST_DIRS_TO_BE_CREATED"
make_dirs "$DEST_DIRS_TO_BE_CREATED"

FORMAT="%P\t%T@\n"

if [ "$IGNOREFILE" = "" ]
then
	find "$SRC" -type f -printf "$FORMAT"  | sort > "$SRC_FILES"
	find "$DEST" -type f -printf "$FORMAT" | sort > "$DEST_FILES"
else
	find "$SRC" -type f -printf "$FORMAT"  | grep -f "$IGNOREFILE" -v | sort > "$SRC_FILES"
	find "$DEST" -type f -printf "$FORMAT" | grep -f "$IGNOREFILE" -v | sort > "$DEST_FILES"
fi


diff "$SRC_FILES" "$DEST_FILES" | grep '^>' | cut -b 3- | cut -f 1 > "$DEST_FILES_TO_BE_REMOVED"
diff "$SRC_FILES" "$DEST_FILES" | grep '^<' | cut -b 3- | cut -f 1 > "$DEST_FILES_TO_BE_CREATED"

echo "FILES TO BE REMOVED: $(number_of_lines "$DEST_FILES_TO_BE_REMOVED")"
display_lines "$DEST_FILES_TO_BE_REMOVED"
remove_files "$DEST_FILES_TO_BE_REMOVED"

echo "FILES TO BE CREATED: $(number_of_lines "$DEST_FILES_TO_BE_CREATED")"
display_lines "$DEST_FILES_TO_BE_CREATED"
make_files "$DEST_FILES_TO_BE_CREATED"

rm -r "$TEMP_DIR"
