#############################################################################
# CMD-SYNC                                                                  #
#                                                                           #
# A bash-script for making the file structure of a *destination directory*  #
# identical to the file structure of a *source directory* (without changing #
# the source), where each destination file is the result of applying a      #
# user-specified *shell command* to the corresponding source file.          #
#                                                                           #
# The script uses GNU find for listing the path and modification-time of    #
# each file, and GNU diff for determining the least amount of changes       #
# required. If a file named '.cmd-sync-ignore' is present immediately       #
# inside the *source directory*, each line of which is a regular expression #
# that can be interpreted by GNU grep, the script will ignore files whose   #
# path matches either of these expressions.                                 #
#                                                                           #
# Written by Eric Johannesson, eric@ericjohannesson.com                     #
#############################################################################

set -e	# Abort if something fails

print_usage(){
echo "Usage:"
echo ""
echo "  bash cmd-sync.sh"
echo "      '<shell command containing expressions '\$IN' and '\$OUT'>'"
echo "       <path to source directory>"
echo "       <path to destination directory> [ --dry-run ]"
echo ""
echo "Examples:"
echo ""
echo "- Make the destination identical to the source:"
echo "  bash cmd-sync.sh 'cp \$IN \$OUT' path/to/directory path/to/copied_directory"
echo ""
echo "- Make the destination an encrypted version of the source:"
echo "  bash cmd-sync.sh 'gpg --encrypt --recipient some@email.com --output \$OUT \$IN' path/to/directory path/to/encrypted_directory"
echo ""
echo "- Make the destination a decrypted version of the source:"
echo "  bash cmd-sync.sh 'gpg --decrypt --output \$OUT \$IN' path/to/encrypted_directory path/to/directory"
}

if [ $# -lt 3 ]
then
	print_usage
	exit 2
fi

if [ ! -d $2 ]
then
	echo "There is no directory with the name '$2'"
	exit 2
fi

if [ ! -d $3 ]
then
	mkdir -p $3
fi


CMD=$(echo $1 | sed 's/ \$IN / "$IN" /g' | sed 's/^\$IN /"$IN" /g' | sed 's/ \$IN$/ "$IN"/g' | sed 's/ \$OUT / "$OUT" /g' | sed 's/^\$OUT /"$OUT" /g' | sed 's/ \$OUT$/ "$OUT"/g')
SRC=$(realpath $2)
DEST=$(realpath $3)

if [ "$4" = "--dry-run" ]
then
	echo "DRY RUN (destination will not be modified)"
	DRY_RUN=1
else
	if [ "$4" = "" ]
	then
		DRY_RUN=0
	else
		print_usage
		exit 2
	fi
fi

remove_dirs(){
	if [ $DRY_RUN -eq 0 ]
	then
		while read LINE
		do
			if [ -d "$DEST/$LINE" ]
			then
				rm -r "$DEST/$LINE"
			fi
		done < $1
	fi
}


make_dirs(){
	if [ $DRY_RUN -eq 0 ]
	then
		while read LINE
		do
			mkdir -p "$DEST/$LINE"
		done < $1
	fi
}

remove_files(){
	if [ $DRY_RUN -eq 0 ]
	then
		while read LINE
		do
			rm "$DEST/$LINE"
		done < $1
	fi
}


make_files(){
	if [ $DRY_RUN -eq 0 ]
	then
		while read LINE
		do
			IN="$SRC/$LINE"
			OUT="$DEST/$LINE"
			eval $CMD
			touch "$OUT" -r "$IN"
		done < $1
	fi
}

display_lines(){
	sed 's/^/\t/' $1
}

number_of_lines(){
	wc -l $1 | cut -f 1 -d ' '
}

ignore_file_exists(){
	if [ -f $SRC/.cmd-sync-ignore ]
	then
		if [ $(file -i $SRC/.cmd-sync-ignore | cut -f 2 -d ' ') = "text/plain;" ]
		then
			echo 1
		else
			echo 0
		fi
	else
	echo 0
	fi
}

DATE=$(date "+%Y-%m-%d-%H.%M.%S")
TEMP_DIR=$HOME/.cmd-sync_$DATE
SRC_DIRS=$TEMP_DIR/src.dirs
DEST_DIRS=$TEMP_DIR/dest.dirs
SRC_FILES=$TEMP_DIR/src.files
DEST_FILES=$TEMP_DIR/dest.files
DEST_DIRS_TO_BE_REMOVED=$TEMP_DIR/dest.dirs.to.be.removed
DEST_DIRS_TO_BE_CREATED=$TEMP_DIR/dest.dirs.to.be.created
DEST_FILES_TO_BE_REMOVED=$TEMP_DIR/dest.files.to.be.removed
DEST_FILES_TO_BE_CREATED=$TEMP_DIR/dest.files.to.be.created

mkdir -p $TEMP_DIR

if [ $(ignore_file_exists) -eq 1 ]
then
	find $SRC -type d -printf "%P\n" | grep -f $SRC/.cmd-sync-ignore -v | sort > $SRC_DIRS
else
	find $SRC -type d -printf "%P\n" | sort > $SRC_DIRS
fi

find $DEST -type d -printf "%P\n" | sort > $DEST_DIRS

diff $SRC_DIRS $DEST_DIRS | grep '^>' | cut -b 3- > $DEST_DIRS_TO_BE_REMOVED
diff $SRC_DIRS $DEST_DIRS | grep '^<' | cut -b 3- > $DEST_DIRS_TO_BE_CREATED

echo "DIRECTORIES TO BE REMOVED: $(number_of_lines $DEST_DIRS_TO_BE_REMOVED)"
display_lines $DEST_DIRS_TO_BE_REMOVED
remove_dirs $DEST_DIRS_TO_BE_REMOVED

echo "DIRECTORIES TO BE CREATED: $(number_of_lines $DEST_DIRS_TO_BE_CREATED)"
display_lines $DEST_DIRS_TO_BE_CREATED
make_dirs $DEST_DIRS_TO_BE_CREATED

FORMAT="%P\t%T@\n"

if [ $(ignore_file_exists) -eq 1 ]
then
	find $SRC -type f -printf $FORMAT | grep -f $SRC/.cmd-sync-ignore -v |sort > $SRC_FILES
else
	find $SRC -type f -printf $FORMAT | sort > $SRC_FILES
fi

find $DEST -type f -printf $FORMAT | sort > $DEST_FILES

diff $SRC_FILES $DEST_FILES | grep '^>' | cut -b 3- | cut -f 1 > $DEST_FILES_TO_BE_REMOVED
diff $SRC_FILES $DEST_FILES | grep '^<' | cut -b 3- | cut -f 1 > $DEST_FILES_TO_BE_CREATED

echo "FILES TO BE REMOVED: $(number_of_lines $DEST_FILES_TO_BE_REMOVED)"
display_lines $DEST_FILES_TO_BE_REMOVED
remove_files $DEST_FILES_TO_BE_REMOVED

echo "FILES TO BE CREATED: $(number_of_lines $DEST_FILES_TO_BE_CREATED)"
display_lines $DEST_FILES_TO_BE_CREATED
make_files $DEST_FILES_TO_BE_CREATED

rm -r $TEMP_DIR
