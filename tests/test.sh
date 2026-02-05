echo "#copy:"
bash ../cmd-sync.sh --ignore input/ignorefile 'cp $IN $OUT' input/files output/copied_files

echo "#encrypt:"
bash ../cmd-sync.sh --ignore input/ignorefile 'gpg --encrypt --batch --yes --no-tty --quiet --recipient some@email.com --output $OUT $IN' input/files output/encrypted_files

echo "#decrypt:"
bash ../cmd-sync.sh --ignore input/ignorefile 'gpg --decrypt --batch --yes --skip-verify --quiet --output $OUT $IN' output/encrypted_files output/files

echo "#redact --dry-run:"
bash ../cmd-sync.sh --dry-run --ignore input/ignorefile 'grep "hello" -v $IN > $OUT' input/files output/files

echo "# diff -r --color expected_output/files output/files:"
diff -r --color expected_output/files output/files

echo "# diff -r --color expected_output/copied_files output/copied_files:"
diff -r --color expected_output/copied_files output/copied_files

