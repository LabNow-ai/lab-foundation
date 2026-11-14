#! /bin/sh
set -ex

echo "Setup mirror config for CERNET..."

export TZ="${TZ:-Asia/Shanghai}"
sudo ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" | sudo tee /etc/timezone >/dev/null
echo "Setup timezone, current date: $(date)"

OS_ID=$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"')
echo "Found ${OS_ID} system, setting mirror for ${OS_ID}"

FILE_DEB=$([ -f /etc/apt/sources.list.d/${OS_ID}.sources ] && echo /etc/apt/sources.list.d/${OS_ID}.sources || echo /etc/apt/sources.list)
if [ -f "$FILE_DEB" ]; then
  sudo sed -i 's|mirrors.*.com/ubuntu|mirrors.cernet.edu.cn/ubuntu|g'       "$FILE_DEB"
  sudo sed -i 's|archive.ubuntu.com/ubuntu|mirrors.cernet.edu.cn/ubuntu|g'  "$FILE_DEB"
  sudo sed -i 's|security.ubuntu.com/ubuntu|mirrors.cernet.edu.cn/ubuntu|g' "$FILE_DEB"
  sudo sed -i 's|deb.debian.org/debian|mirrors.cernet.edu.cn/debian|g'      "$FILE_DEB"
  echo "Finished setting Ubuntu/Debian mirror"
fi

[ -f /etc/apt/sources.list.d/pgdg.list ] && sudo sed -i 's|apt.postgresql.org/pub|mirrors.cernet.edu.cn/postgresql|' /etc/apt/sources.list.d/pgdg.list

if command -v python >/dev/null 2>&1 ; then
  echo "Found python, setting pypi source in /etc/pip.conf"
  sudo tee /etc/pip.conf >/dev/null <<EOF
[global]
progress_bar=off
root-user-action=ignore
retries=5
timeout=180
trusted-host=pypi.python.org pypi.org files.pythonhosted.org mirrors.cernet.edu.cn
index-url=https://mirrors.cernet.edu.cn/pypi/web/simple/
EOF
  pip config list
fi

for cmd in npm pnpm yarn bun; do
  if command -v "$cmd" >/dev/null 2>&1 ; then
    echo "Found $cmd, setting mirror"
    "$cmd" config set registry https://registry.npmmirror.com
    "$cmd" config list
    echo
  fi
done

if command -v go >/dev/null 2>&1 ; then
  echo "Found golang, setting GOPROXY"
  export GOPROXY=https://mirrors.aliyun.com/goproxy/
  go env | grep 'PROXY'
fi

if command -v R >/dev/null 2>&1 ; then
  echo "Found R, setting CRAN mirror"
  echo 'options(repos=structure(c(CRAN="https://mirrors.cernet.edu.cn/CRAN/")))' | sudo tee -a /etc/R/Rprofile.site >/dev/null
  R -e "options('repos');"
fi
