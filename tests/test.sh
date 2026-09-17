set -e # Abort if something fails

echo "# copy with --ignore:"
../bin/cmdsync \
  --ignore input/ignorefile \
  --cmd 'cp $IN $OUT' \
  --src input/files \
  --dest output/copied_files

echo "# diff -r expected_output/copied_files output/copied_files:"
diff -r --color expected_output/copied_files output/copied_files

echo "# encrypt with --ignore:"
../bin/cmdsync \
  --ignore input/ignorefile \
  --cmd 'gpg --encrypt --batch --yes --no-tty --quiet --recipient some@email.com --output $OUT $IN' \
  --src input/files \
  --dest output/encrypted_files

echo "# decrypt with --ignore:"
../bin/cmdsync \
  --ignore input/ignorefile \
  --cmd 'gpg --decrypt --batch --yes --skip-verify --quiet --output $OUT $IN' \
  --src output/encrypted_files \
  --dest output/files

echo "# redact with --dry-run:"
../bin/cmdsync \
  --dry-run \
  --cmd 'grep "hello" -v $IN > $OUT' \
  --src input/files \
  --dest output/files


echo "# diff -r expected_output/files output/files:"
diff -r --color expected_output/files output/files


echo "# copy:"
../bin/cmdsync \
  --cmd 'cp $IN $OUT' \
  --src input/files \
  --dest output/new_files \

echo "# diff -r input/files output/new_files:"
diff -r --color input/files output/new_files


echo "# copy with --backup:"
../bin/cmdsync \
  --cmd 'cp $IN $OUT' \
  --src input/new_files \
  --dest output/new_files \
  --backup output/backup \
  --suffix ".old"

echo "# diff -r input/new_files output/new_files:"
diff -r --color input/new_files output/new_files

echo "# diff -r expected_output/backup output/backup:"
diff -r --color expected_output/backup output/backup
