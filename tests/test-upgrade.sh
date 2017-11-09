if [ "${IRR_ACTION}" == "leapfrogupgrade" ]; then
  tests/test-leapfrog.sh
elif [ "${IRR_ACTION}" == "minorupgrade" ]; then
  tests/test-minor.sh
else
  echo "FAIL!"
  echo "IRR_ACTION '${IRR_ACTION}' is not supported."
  exit 99
fi
