set -e # Abort if something fails

echo "# copy with --ignore:"
bash ../src/cmdsync.sh \
  --ignore input/ignorefile \
  --cmd 'cp $IN $OUT' \
  --src input/files \
  --dest output/copied_files

echo "# diff -r expected_output/copied_files output/copied_files:"
diff -r expected_output/copied_files output/copied_files

echo "# encrypt with --ignore:"
bash ../src/cmdsync.sh \
  --ignore input/ignorefile \
  --cmd 'gpg --symmetric --quiet --batch --yes --passphrase test --output $OUT $IN' \
  --src input/files \
  --dest output/encrypted_files

echo "# decrypt with --ignore:"
bash ../src/cmdsync.sh \
  --ignore input/ignorefile \
  --cmd 'gpg --decrypt --quiet --batch --yes --passphrase test --output $OUT $IN' \
  --src output/encrypted_files \
  --dest output/decrypted_files

echo "# redact with --dry-run:"
bash ../src/cmdsync.sh \
  --dry-run \
  --cmd 'grep "hello" -v $IN > $OUT' \
  --src input/files \
  --dest output/decrypted_files


echo "# diff -r expected_output/files output/files:"
diff -r expected_output/files output/decrypted_files


echo "# copy files:"
bash ../src/cmdsync.sh \
  --cmd 'cp $IN $OUT' \
  --src input/files \
  --dest output/files

echo "# make changed_files:"
bash ../src/cmdsync.sh \
  --cmd 'cp $IN $OUT' \
  --src input/files \
  --dest input/changed_files

rm -r 'input/changed_files/dir 2'
rm 'input/changed_files/file 3'
echo 'changed' >> 'input/changed_files/dir 1/file 3'

echo "# copy changed_files with --backup:"
bash ../src/cmdsync.sh \
  --cmd 'cp $IN $OUT' \
  --src input/changed_files \
  --dest output/files \
  --backup output/backup \
  --suffix ".old"

echo "# diff -r input/changed_files output/files:"
diff -r input/changed_files output/files

echo "# diff -r expected_output/backup output/backup:"
diff -r expected_output/backup output/backup


