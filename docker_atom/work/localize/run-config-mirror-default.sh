#! /bin/sh
set -ex

export TZ="${TZ:-Asia/Shanghai}"
sudo ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" | sudo tee /etc/timezone >/dev/null
echo "Setup timezone, current date: $(date)"

if [ -f /etc/apt/sources.list ] ; then
  echo "Found Ubuntu/debian system, using default ubuntu/debian mirror"
fi

if command -v python >/dev/null 2>&1 ; then
  echo "Found python, using default pypi source in /etc/pip.conf"
  pip config list
fi

if command -v npm >/dev/null 2>&1 ; then
  echo "Found npm, using default npm mirror"
  npm config list
fi

if command -v go >/dev/null 2>&1 ; then
  echo "Found golang, getting GO env:"
  go env | sort
fi

if command -v R >/dev/null 2>&1 ; then
  echo "Found R, getting CRAN mirror"
  R -e "options('repos');"
fi
