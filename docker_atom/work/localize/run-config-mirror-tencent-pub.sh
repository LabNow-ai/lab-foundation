#! /bin/sh
set -ex

echo "Setup mirror config for Tencent Cloud VPC Environment..."

export TZ=${TZ:="Asia/Shanghai"}
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ >/etc/timezone
echo "Setup timezone, current date: $(date)"

eval "export $(cat /etc/os-release  | grep ID=)" && export OS_ID=${ID} && echo "Found ${ID} system, setting mirror for ${ID}"

FILE_DEB=$([ -f /etc/apt/sources.list.d/${OS_ID}.sources  ] && echo /etc/apt/sources.list.d/${OS_ID}.sources || echo /etc/apt/sources.list )
if [ -f $FILE_DEB ]; then
  sed -i 's/mirrors.*.com\/ubuntu/mirrors.tencent.com\/ubuntu/'       $FILE_DEB
  sed -i 's/archive.ubuntu.com\/ubuntu/mirrors.tencent.com\/ubuntu/'  $FILE_DEB
  sed -i 's/security.ubuntu.com\/ubuntu/mirrors.tencent.com\/ubuntu/' $FILE_DEB
  sed -i 's/deb.debian.org\/debian/mirrors.tencent.com\/debian/'      $FILE_DEB
  echo "Finished setting ubuntu/debian mirror"
fi

[ -f /etc/apt/sources.list.d/pgdg.list ] && sed -i 's/apt.postgresql.org\/pub/mirrors.tencent.com\/postgresql/' /etc/apt/sources.list.d/pgdg.list

if [ -f "$(which python)" ] ; then
  echo "Found python, setting pypi source in /etc/pip.conf"
  cat >/etc/pip.conf <<EOF
[global]
progress_bar=off
root-user-action=ignore
retries=5
timeout=180
trusted-host=pypi.python.org pypi.org files.pythonhosted.org mirrors.tencent.com
index-url=http://mirrors.tencent.com/pypi/simple/
EOF
  pip config list
fi

for cmd in npm pnpm yarn bun; do
  if [ -f "$(which $cmd)" ] ; then
    echo "Found $cmd, setting mirror"
    "$cmd" config set registry https://registry.npmmirror.com
    "$cmd" config list
    echo
  fi
done

if [ -f "$(which go)" ] ; then
  echo "Found golang, setting GOPROXY"
  export GOPROXY=https://mirrors.tencent.com/go/
  go env | grep 'PROXY'
fi

if [ -f "$(which R)" ] ; then
  echo "Found R, setting CRAN mirror"
  echo "options(repos=structure(c(CRAN=\"http://mirrors.tencent.com/CRAN/\")))" >> /etc/R/Rprofile.site
  R -e "options('repos');"
fi
