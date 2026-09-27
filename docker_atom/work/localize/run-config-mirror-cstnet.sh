#! /bin/sh
set -ex

echo "Setup mirror config for CSTNET (CERNET MirrorZ)..."

export TZ=${TZ:="Asia/Shanghai"}
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ >/etc/timezone
echo "Setup timezone, current date: $(date)"

eval "export $(cat /etc/os-release | grep ID=)" && export OS_ID=${ID} && echo "Found ${ID} system, setting mirror for ${ID}"

FILE_DEB=$([ -f /etc/apt/sources.list.d/${OS_ID}.sources ] && echo /etc/apt/sources.list.d/${OS_ID}.sources || echo /etc/apt/sources.list)
if [ -f "$FILE_DEB" ]; then
  sed -i 's|mirrors.*.com/ubuntu|mirrors.cernet.edu.cn/ubuntu|g' "$FILE_DEB"
  sed -i 's|archive.ubuntu.com/ubuntu|mirrors.cernet.edu.cn/ubuntu|g' "$FILE_DEB"
  sed -i 's|security.ubuntu.com/ubuntu|mirrors.cernet.edu.cn/ubuntu|g' "$FILE_DEB"
  sed -i 's|deb.debian.org/debian|mirrors.cernet.edu.cn/debian|g' "$FILE_DEB"
  echo "Finished setting Ubuntu/Debian mirror"
fi

if command -v python >/dev/null 2>&1; then
  echo "Found python, setting PyPI source in /etc/pip.conf"
  cat >/etc/pip.conf <<EOF_PIP
[global]
progress_bar=off
root-user-action=ignore
retries=5
timeout=180
trusted-host=mirrors.cernet.edu.cn
index-url=https://mirrors.cernet.edu.cn/pypi/web/simple
EOF_PIP
  pip config list
fi

if command -v R >/dev/null 2>&1; then
  echo "Found R, setting CRAN mirror"
  echo 'options(repos=structure(c(CRAN="https://mirrors.cernet.edu.cn/CRAN/")))' >> /etc/R/Rprofile.site
  R -e "options('repos');"
fi
