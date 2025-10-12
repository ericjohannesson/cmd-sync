echo "#copy:"
bash ../cmd-sync.sh 'cp "$IN" "$OUT"' input/files output/copied_files

echo "#encrypt:"
bash ../cmd-sync.sh 'gpg --encrypt --batch --yes --no-tty --quiet --recipient eric@ericjohannesson.com --output "$OUT" "$IN"' input/files output/encrypted_files

echo "#decrypt:"
bash ../cmd-sync.sh 'gpg --decrypt --batch --yes --skip-verify --quiet --output "$OUT" "$IN"' output/encrypted_files output/files

echo "# diff -r expected_output/files output/files:"
diff -r expected_output/files output/files

echo "# diff -r expected_output/copied_files output/copied_files:"
diff -r expected_output/copied_files output/copied_files

