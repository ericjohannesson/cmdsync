echo "#copy:"
../bin/cmdsync \
  --ignore input/ignorefile \
  --cmd 'cp $IN $OUT' \
  --src input/files \
  --dest output/copied_files

echo "#encrypt:"
../bin/cmdsync \
  --ignore input/ignorefile \
  --cmd 'gpg --encrypt --batch --yes --no-tty --quiet --recipient some@email.com --output $OUT $IN' \
  --src input/files \
  --dest output/encrypted_files

echo "#decrypt:"
../bin/cmdsync \
  --ignore input/ignorefile \
  --cmd 'gpg --decrypt --batch --yes --skip-verify --quiet --output $OUT $IN' \
  --src output/encrypted_files \
  --dest output/files

echo "#redact --dry-run:"
../bin/cmdsync \
  --dry-run \
  --ignore input/ignorefile \
  --cmd 'grep "hello" -v $IN > $OUT' \
  --src input/files \
  --dest output/files

echo "# diff -r expected_output/files output/files:"
diff -r --color expected_output/files output/files

echo "# diff -r expected_output/copied_files output/copied_files:"
diff -r --color expected_output/copied_files output/copied_files

