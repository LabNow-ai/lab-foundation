. /opt/utils/script-utils.sh


setup_mamba() {
  # Notice: mamba use $CONDA_PREFIX to locate base env
     local UNAME=$(uname | tr '[:upper:]' '[:lower:]') \
  && local ARCH=$(uname -m | sed -e 's/x86_64/64/') \
  && local VER_MICROMAMBA_REQ="${1:-}" \
  && local VERS_MICROMAMBA=$(curl_fsSL "https://api.github.com/repos/mamba-org/micromamba-releases/releases?per_page=50" | grep -oP '"tag_name":\s*"\K[^"]+' | grep -viE '(alpha|beta|rc)' | sort -rV) \
  && if [ -n "${VER_MICROMAMBA_REQ}" ]; then
       local VER_MICROMAMBA_RE=${VER_MICROMAMBA_REQ#v} \
       && VER_MICROMAMBA_RE=$(printf '%s' "$VER_MICROMAMBA_RE" | sed 's/[.]/\\./g') \
       && local VER_MICROMAMBA=$(echo "${VERS_MICROMAMBA}" | grep -m1 -E "^${VER_MICROMAMBA_RE}([.-]|$)")
     else
       local VER_MICROMAMBA=$(echo "${VERS_MICROMAMBA}" | head -1)
     fi \
  && [ -n "${VER_MICROMAMBA}" ] \
  && local URL_MICROMAMBA="https://github.com/mamba-org/micromamba-releases/releases/download/${VER_MICROMAMBA}/micromamba-${UNAME}-${ARCH}.tar.bz2" \
  && echo "Downloading micromamba ${VER_MICROMAMBA} from ${URL_MICROMAMBA}" \
  && sudo mkdir -pv /opt/mamba /etc/conda \
  && install_tar_bz "$URL_MICROMAMBA" bin/micromamba && sudo mv /opt/bin/micromamba /opt/mamba/mamba \
  && sudo ln -sf /opt/mamba/mamba /usr/bin/ \
  && sudo touch /etc/conda/.condarc && sudo ln -sf /etc/conda/.condarc /opt/conda/.condarc \
  && printf "channels:\n"       | sudo tee -a /etc/conda/.condarc \
  && printf "  - conda-forge\n" | sudo tee -a /etc/conda/.condarc \
  && cat /etc/conda/.condarc ;
  type mamba && echo "@ Version of mamba: $(mamba info)" || return 1 ;
}


setup_conda_postprocess() {
  type conda || return 1 ;

  # If python exists, set pypi source
  if [ -f "$(which python)" ]; then
    sudo tee /etc/pip.conf >/dev/null <<EOF
[global]
progress_bar=off
root-user-action=ignore
# retries=5
# timeout=10
trusted-host=pypi.python.org pypi.org files.pythonhosted.org
# index-url=https://pypi.python.org/simple
EOF
  fi

  echo 'export PATH=${CONDA_PREFIX:-"/opt/conda"}/bin:${PATH}'	| sudo tee -a /etc/profile.d/path-conda.sh
  sudo ln -sf "${CONDA_PREFIX}/bin/conda" /usr/bin/

     sudo conda config --system --prepend channels conda-forge \
  && sudo conda config --system --set auto_update_conda false  \
  && sudo conda config --system --set show_channel_urls true   \
  && sudo conda config --system --set report_errors false \
  && sudo conda config --system --set channel_priority strict \
  && sudo conda update --all --quiet --yes ;

  # remove non-necessary folder/symlink "python3.1" exists
  sudo rm -rf "${CONDA_PREFIX}"/bin/python3.1 "${CONDA_PREFIX}"/lib/python3.1 ;

  # These conda pkgs shouldn't be removed (otherwise will cause RemoveError) since they are directly required by conda: pip setuptools pycosat pyopenssl requests ruamel_yaml
  #    CONDA_PY_PKGS=$(conda list | grep "py3" | cut -d " " -f 1 | sed "/#/d;/conda/d;/pip/d;/setuptools/d;/pycosat/d;/pyopenssl/d;/requests/d;/ruamel_yaml/d;") \
  # && conda remove --force -yq "${CONDA_PY_PKGS}" \
  # && pip install -UIq pip setuptools "${CONDA_PY_PKGS}" \
  # && rm -rf "${CONDA_PREFIX}"/pkgs/*

  # Print Conda and Python packages information in the docker build log
  echo "@ Version of Conda & Python:" && conda info && conda list | grep -v "<pip>" ;
}

setup_conda_with_mamba() {
     local VERSION_PYTHON=${1:-"3.13"} \
  && local PREFIX="${CONDA_PREFIX:-/opt/conda}" \
  && sudo mkdir -pv "${PREFIX}" \
  && sudo mamba install -y --root-prefix="${PREFIX}" --prefix="${PREFIX}" -c "conda-forge" conda pip python="${VERSION_PYTHON}" \
  && setup_conda_postprocess ;
}

setup_conda_download() {
  ## https://docs.conda.io/projects/miniconda/en/latest/index.html
     local URL_CONDA="https://repo.continuum.io/miniconda/Miniconda3-latest-$(uname)-$(arch).sh" \
  && curl_fsSL "$URL_CONDA" -o /tmp/conda.sh \
  && sudo mkdir -pv "${CONDA_PREFIX}" && sudo bash /tmp/conda.sh -f -b -p "${CONDA_PREFIX}/" \
  && rm -rf /tmp/conda.sh \
  && setup_conda_postprocess ;
}

setup_nvtop() {
  ## The compilation requires CMake 3.18 or higher, while the default version in CUDA 11.2 images is 3.16.3
     curl_fsSL https://apt.kitware.com/keys/kitware-archive-latest.asc | sudo gpg --dearmor -o /usr/share/keyrings/kitware-archive-keyring.gpg \
  && echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/kitware.list \
  && sudo apt-get -qq update -yq --fix-missing && sudo apt-get -qq install -yq --no-install-recommends cmake ;

  # Install Utilities "nvtop" from source: libdrm-dev libsystemd-dev used by AMD/Intel GPU support, libudev-dev used by ubuntu18.04
     local LIB_PATH=$(find / -name "libnvidia-ml*" 2>/dev/null) \
  && local DIRECTORY=$(pwd) && cd /tmp \
  && sudo apt-get -qq update --fix-missing \
  && sudo apt-get -qq install -y --no-install-recommends libncurses5-dev libdrm-dev libsystemd-dev libudev-dev \
  && git clone https://github.com/Syllo/nvtop.git \
  && mkdir -pv nvtop/build && cd nvtop/build \
  && cmake .. -DCMAKE_LIBRARY_PATH="$(dirname ${LIB_PATH})" -DNVIDIA_SUPPORT=ON -DAMDGPU_SUPPORT=ON -DINTEL_SUPPORT=ON \
  && make && sudo make install \
  && cd "${DIRECTORY}" && rm -rf /tmp/nvtop \
  && sudo apt-get -qq remove -y libncurses5-dev libdrm-dev libsystemd-dev libudev-dev ;
  type nvtop && echo "Version of nvtop: $(nvtop --version)" || return 1 ;
}


setup_java_base() {
  ## Use the first arg and then VERSION_JDK to specify JDK major version. If not specified, will try the latest.
  ## for JDK>20 (25, 21), install oracle version, for earlier version (17, 11 ,8), install adoptium version.
  ## Reason: for JDK 21 and 23, there are some issues with adoptium distribution (e.g. no alpine version for JDK 23, and no linux/arm64 version for JDK 21), while oracle distribution works fine.
  ## For JDK 17, 11 and 8, both distributions are fine, but we prefer adoptium since it's more lightweight without extra tools (e.g. mission control) and also has alpine version.

     local VER_JDK_MAJOR="${1:-${VERSION_JDK:-latest}}" \
  && local ARCH=$(uname -m | sed -e 's/x86_64/x64/') \
  && local IS_ALPINE=$(grep -q 'ID=alpine' /etc/os-release && echo true || echo false) \
  && echo "Installing JDK ${ARCH} of specified major version: ${VER_JDK_MAJOR}" ;
  
  local VER_JDK="$VER_JDK_MAJOR" ;
  if [ "$VER_JDK_MAJOR" = "latest" ] || { case "$VER_JDK_MAJOR" in ''|*[!0-9]*) false ;; *) [ "$VER_JDK_MAJOR" -gt 20 ] ;; esac; }; then
    local PAGE_JDK_DOWNLOAD="https://www.oracle.com/java/technologies/downloads/"
    local PAGE_JDK=$(curl_fsSL "$PAGE_JDK_DOWNLOAD" || { echo "Failed to fetch Oracle JDK download page" && return 1; } )

    if [ "$VER_JDK_MAJOR" = "latest" ]; then
      VER_JDK=$(echo "$PAGE_JDK" | grep -oE 'jdk-[0-9]+' | sed 's/jdk-//' | sort -rV | head -1) ;  
    fi ;

       local URL_JDK_DOWNLOAD=$(echo "${PAGE_JDK}" | grep "tar.gz" | grep "http" | grep -v sha256 | grep "${ARCH}" | grep -i "$(uname)" | grep -oP "(https?://[^\s<>\'\"]*)" | grep "jdk-${VER_JDK}" | head -n 1) \
    && local VER_JDK_MINOR=$(echo "$URL_JDK_DOWNLOAD" | grep -Po '[\d\.]{3,}' | head -n1) ;
  else
       local URL_JDK_adoptium="https://api.github.com/repos/adoptium/temurin${VER_JDK_MAJOR}-binaries/releases/latest" \
    && local URL_JDK_DOWNLOAD=$(
      curl_fsSL "$URL_JDK_adoptium" | grep 'tar.gz' | grep -vE '.sha256|.sig|.json|debug|test' | grep "${ARCH}" | grep -i "$(uname)" \
      | grep -oP "(https?://[^\s<>\'\"]*)" \
      | if [ "$IS_ALPINE" = true ]; then grep -E 'alpine'; else grep -v 'alpine'; fi \
      | head -n1
    ) ;
  fi

  if [ -z "$URL_JDK_DOWNLOAD" ]; then
    echo "Failed to find a JDK ${VER_JDK_MAJOR} download for ${ARCH} (Alpine: ${IS_ALPINE})" >&2
    return 1
  fi

  echo "Installing JDK version ${VER_JDK} from: ${URL_JDK_DOWNLOAD}" ;
  install_tar_gz "${URL_JDK_DOWNLOAD}" && sudo mv /opt/jdk* /opt/jdk && sudo ln -sf /opt/jdk/bin/* /usr/bin/ ;
  type java  && echo "@ Version of Java (java):  $(java -version)"  || return 1 ;
  type javac && echo "@ Version of Java (javac): $(javac -version)" || return 1 ;
}


setup_java_maven() {
     local VER_MAVEN="${1:-3}" \
  && local ATOM_MAVEN=$(curl_fsSL https://maven.apache.org/docs/history.html | grep '/ref/') \
  && local VERS_MAVEN=$(echo "${ATOM_MAVEN}" | grep -oP '(?<=/ref/)[0-9]+\.[0-9]+(\.[0-9]+)?(-[a-z]+-[0-9]+)?(?=/)' | grep -viE '(alpha|beta|rc)' | sort -rV) \
  && local VER_MAVEN_RE=${VER_MAVEN#v} \
  && VER_MAVEN_RE=$(printf '%s' "$VER_MAVEN_RE" | sed 's/[.]/\\./g') \
  && VER_MAVEN=$(echo "${VERS_MAVEN}" | grep -m1 -E "^${VER_MAVEN_RE}([.-]|$)") \
  && [ -n "${VER_MAVEN}" ] \
  && local URL_MAVEN="https://archive.apache.org/dist/maven/maven-3/${VER_MAVEN}/binaries/apache-maven-${VER_MAVEN}-bin.zip" \
  && echo "Downloading Maven version ${VER_MAVEN} from: ${URL_MAVEN}" \
  && install_zip "${URL_MAVEN}" \
  && sudo mv "/opt/apache-maven-${VER_MAVEN}" /opt/maven \
  && sudo ln -sf /opt/maven/bin/mvn* /usr/bin/ ;
  type mvn && echo "@ Version of Maven: $(mvn --version)" || return 1 ;
}


setup_node_base() {
     local VER_NODEJS_REQ="${1:-}" \
  && local UNAME=$(uname | tr '[:upper:]' '[:lower:]') \
  && local ARCH=$(uname -m | sed -e 's/x86_64/x64/' -e 's/aarch64/arm64/') \
  && local VERS_NODEJS=$(curl_fsSL "https://api.github.com/repos/nodejs/node/releases?per_page=50" | grep -Po '(?<="tag_name": ")[^"]+' | grep -vi alpha | grep -Po '\d[\d.]+' | sort -rV) \
  && if [ -n "${VER_NODEJS_REQ}" ]; then
          local VER_NODEJS_RE=${VER_NODEJS_REQ#v} && VER_NODEJS_RE=$(printf '%s' "$VER_NODEJS_RE" | sed 's/[.]/\\./g') \
       && local VER_NODEJS=$(echo "${VERS_NODEJS}" | grep -m1 -E "^${VER_NODEJS_RE}([.-]|$)")
     else
          local VER_NODEJS=$(echo "${VERS_NODEJS}" | head -1)
     fi \
  && [ -n "${VER_NODEJS}" ] \
  && local URL_NODEJS="https://nodejs.org/dist/v${VER_NODEJS}/node-v${VER_NODEJS}-${UNAME}-${ARCH}.tar.gz" \
  && echo "Downloading NodeJS version ${VER_NODEJS} from: ${URL_NODEJS}" \
  && install_tar_gz "${URL_NODEJS}" \
  && sudo mv /opt/node* /opt/node \
  && sudo ln -sf /opt/node/bin/n* /usr/bin/ \
  && echo 'export PATH=${PATH}:/opt/node/bin' | sudo tee -a /etc/profile.d/path-node.sh \
  && . /etc/profile.d/path-node.sh \
  && sudo npm install -g npm ;
  # cd /tmp && corepack enable && yarn set version stable && echo "@ Version of Yarn: $(yarn -v)"
  type node && echo "@ Version of Node and node: $(node -v)" || return 1 ;
  type npm  && echo "@ Version of Node and npm:  $(npm -v)"  || return 1 ;
}

setup_node_pnpm() {
  local VER_PNPM_REQ="${1:-}" UNAME ARCH URL_PNPM TMPDIR ;
     UNAME=$(uname | tr '[:upper:]' '[:lower:]') \
  && ARCH=$(uname -m | sed -e 's/x86_64/x64/' -e 's/aarch64/arm64/' -e 's/armv7l/arm/') \
  && local VERS_PNPM=$(curl_fsSL "https://api.github.com/repos/pnpm/pnpm/releases?per_page=50" | grep -Po '(?<="tag_name": ")[^"]+' | grep -viE '(alpha|beta|rc)' | grep -Po '\d[\d.]+' | sort -rV) \
  && if [ -n "${VER_PNPM_REQ}" ]; then
       local VER_PNPM_RE=${VER_PNPM_REQ#v} \
       && VER_PNPM_RE=$(printf '%s' "$VER_PNPM_RE" | sed 's/[.]/\\./g') \
       && local VER_PNPM=$(echo "${VERS_PNPM}" | grep -m1 -E "^${VER_PNPM_RE}([.-]|$)")
     else
       local VER_PNPM=$(echo "${VERS_PNPM}" | head -1)
     fi \
  && [ -n "${VER_PNPM}" ] \
  && sudo mkdir -p /opt/node/bin /opt/node/pnpm-store \
  && if [ "${VER_PNPM%%.*}" -ge 11 ]; then
       URL_PNPM="https://github.com/pnpm/pnpm/releases/download/v${VER_PNPM}/pnpm-${UNAME}-${ARCH}.tar.gz" \
       && echo "@ Installing pnpm v${VER_PNPM} from: ${URL_PNPM}" \
       && TMPDIR=$(mktemp -d) && curl_fsSL "${URL_PNPM}" | tar -xzf - -C "${TMPDIR}" \
       && sudo mv -f "${TMPDIR}/pnpm" /opt/node/bin/pnpm \
       && { [ -d "${TMPDIR}/dist" ] && sudo rm -rf /opt/node/bin/dist && sudo mv "${TMPDIR}/dist" /opt/node/bin/ ; rm -rf "${TMPDIR}" ; true ; } ;
     else
       URL_PNPM="https://github.com/pnpm/pnpm/releases/download/v${VER_PNPM}/pnpm-${UNAME}-${ARCH}" \
       && echo "@ Installing pnpm v${VER_PNPM} from: ${URL_PNPM}" \
       && sudo curl_fsSL -o /opt/node/bin/pnpm "${URL_PNPM}" ;
     fi \
  && sudo chmod +x /opt/node/bin/pnpm && sudo ln -sf /opt/node/bin/pnpm /usr/local/bin/pnpm \
  && echo 'export PNPM_STORE_DIR=/opt/node/pnpm-store' | sudo tee /etc/profile.d/path-pnpm.sh >/dev/null ;
  type pnpm >/dev/null 2>&1 && echo "@ Version of pnpm: $(pnpm --version)" || return 1 ;
}

setup_node_bun() {
     local VER_BUN_REQ="${1:-}" \
  && local UNAME=$(uname | tr '[:upper:]' '[:lower:]') \
  && local ARCH=$(uname -m | sed -e 's/x86_64/x64/' ) \
  && local VERS_BUN=$(curl_fsSL "https://api.github.com/repos/oven-sh/bun/releases?per_page=50" | grep -Po '(?<="tag_name": ")[^"]+' | grep -Po 'bun-v\K\d+\.\d+\.\d+' | sort -rV) \
  && if [ -n "${VER_BUN_REQ}" ]; then
       local VER_BUN_RE=${VER_BUN_REQ#v} \
       && VER_BUN_RE=$(printf '%s' "$VER_BUN_RE" | sed 's/[.]/\\./g') \
       && local VER_BUN=$(echo "${VERS_BUN}" | grep -m1 -E "^${VER_BUN_RE}([.-]|$)")
     else
       local VER_BUN=$(echo "${VERS_BUN}" | head -1)
     fi \
  && [ -n "${VER_BUN}" ] \
  && local URL_BUN="https://github.com/oven-sh/bun/releases/download/bun-v${VER_BUN}/bun-${UNAME}-${ARCH}.zip" \
  && echo "Downloading bun version ${VER_BUN} from: ${URL_BUN}" \
  && install_zip "${URL_BUN}" \
  && sudo mv /opt/bun-* /opt/bun \
  && sudo ln -sf /opt/bun/bun /usr/bin/ \
  && echo 'export PATH="${PATH}:/opt/bun"' | sudo tee -a /etc/profile.d/path-bun.sh \
  && . /etc/profile.d/path-bun.sh ;
  type bun && echo "@ Version of bun: $(bun -v)" || return $? ;
}


setup_GO() {
     local VER_GO_REQ="${1:-}" \
  && local UNAME=$(uname | tr '[:upper:]' '[:lower:]') \
  && local ARCH=$(dpkg --print-architecture) \
  && local VERS_GO=$(curl_fsSL "https://api.github.com/repos/golang/go/releases?per_page=50" | grep -Po '(?<="tag_name": ")[^"]+' | grep -v 'rc' | grep -Po '\d[\d.]+' | sort -rV) \
  && { [ -n "${VERS_GO}" ] || VERS_GO=$(curl_fsSL "https://go.dev/dl/?mode=json" | grep -Po '(?<="version": "go)\d[\d.]+' | sort -rV) ; } \
  && if [ -n "${VER_GO_REQ}" ]; then
       local VER_GO_RE=${VER_GO_REQ#v} \
       && VER_GO_RE=$(printf '%s' "$VER_GO_RE" | sed 's/[.]/\\./g') \
       && local VER_GO=$(echo "${VERS_GO}" | grep -m1 -E "^${VER_GO_RE}([.-]|$)")
     else
       local VER_GO=$(echo "${VERS_GO}" | head -1)
     fi \
  && [ -n "${VER_GO}" ] \
  && local URL_GO="https://dl.google.com/go/go${VER_GO}.${UNAME}-${ARCH}.tar.gz" \
  && echo "Downloading golang version ${VER_GO} from: ${URL_GO}" \
  && install_tar_gz "${URL_GO}" go \
  && sudo ln -sf /opt/go/bin/go* /usr/bin/ \
  && echo 'export GOROOT="/opt/go"'       | sudo tee -a /etc/profile.d/path-go.sh \
  && echo 'export GOBIN="$GOROOT/bin"'    | sudo tee -a /etc/profile.d/path-go.sh \
  && echo 'export GOPATH="$GOROOT/path"'  | sudo tee -a /etc/profile.d/path-go.sh \
  && echo 'export PATH=$PATH:$GOROOT/bin:$GOPATH/bin' | sudo tee -a /etc/profile.d/path-go.sh \
  && . /etc/profile.d/path-go.sh ;
  type go && echo "@ Version of golang: $(go version)" || return 1 ;
}


setup_rust() {
  curl_fsSL https://sh.rustup.rs | sudo sh -c '
    export CARGO_HOME=/opt/cargo && export RUSTUP_HOME=/opt/rust
    sh -s -- -y --no-modify-path --profile minimal --default-toolchain stable
  '
     echo 'export CARGO_HOME="/opt/cargo"'     | sudo tee -a /etc/profile.d/path-rust.sh > /dev/null \
  && echo 'export RUSTUP_HOME="/opt/rust"'     | sudo tee -a /etc/profile.d/path-rust.sh > /dev/null \
  && echo 'export PATH="$PATH:/opt/cargo/bin"' | sudo tee -a /etc/profile.d/path-rust.sh > /dev/null \
  && . /etc/profile.d/path-rust.sh ;
  type rustup && echo "@ Version of rustup: $(rustup --version)" || return 1 ;
  type rustc  && echo "@ Version of rustc:  $(rustc  --version)" || return 1 ;
}


setup_R_base() {
     local UNAME=$(uname | tr '[:upper:]' '[:lower:]') \
  && curl_fsSL https://cloud.r-project.org/bin/${UNAME}/ubuntu/marutter_pubkey.asc | sudo tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc \
  && echo "deb https://cloud.r-project.org/bin/${UNAME}/ubuntu $(lsb_release -cs)-cran40/" | sudo tee /etc/apt/sources.list.d/cran.list >/dev/null \
  && install_apt  /opt/utils/install_list_R_base.apt \
  && echo "options(repos=structure(c(CRAN=\"https://cloud.r-project.org\")))" | sudo tee -a /etc/R/Rprofile.site \
  && sudo R -e "install.packages(c('devtools'),clean=T,quiet=T);" \
  && sudo R -e "install.packages(c('devtools'),clean=T,quiet=F);" \
  && ( type java && type R && R CMD javareconf || true ) ;
  type R && echo "@ Version of R: $(R --version)" || return 1 ;
}


setup_julia() {
     local VER_JULIA_REQ="${1:-}" \
  && local UNAME=$(uname | tr '[:upper:]' '[:lower:]') \
  && local ARCH_1=$(uname -m) \
  && local ARCH_2=$(uname -m | sed -e 's/x86_64/x64/') \
  && local VERS_JULIA=$(curl_fsSL "https://api.github.com/repos/JuliaLang/julia/releases?per_page=50" | grep -Po '(?<="tag_name": ")[^"]+' | grep -P -v '(rc|alpha|beta)' | grep -Po '\d[\d.]+' | sort -rV) \
  && if [ -n "${VER_JULIA_REQ}" ]; then
       local VER_JULIA_RE=${VER_JULIA_REQ#v} \
       && VER_JULIA_RE=$(printf '%s' "$VER_JULIA_RE" | sed 's/[.]/\\./g') \
       && local VER_JULIA=$(echo "${VERS_JULIA}" | grep -m1 -E "^${VER_JULIA_RE}([.-]|$)")
     else
       local VER_JULIA=$(echo "${VERS_JULIA}" | head -1)
     fi \
  && [ -n "${VER_JULIA}" ] \
  && local VER_JULIA_MAJOR=$(echo "${VER_JULIA}" | cut -d '.' -f1,2) \
  && local URL_JULIA="https://julialang-s3.julialang.org/bin/linux/${ARCH_2}/${VER_JULIA_MAJOR}/julia-${VER_JULIA}-linux-${ARCH_1}.tar.gz" \
  && echo "Downloading Julia version ${VER_JULIA} from: ${URL_JULIA}" \
  && install_tar_gz "$URL_JULIA" \
  && sudo mv /opt/julia-* /opt/julia \
  && sudo ln -fs /opt/julia/bin/julia /usr/bin/julia \
  && sudo mkdir -pv /opt/julia/pkg \
  && echo "import Libdl; push!(Libdl.DL_LOAD_PATH, \"/opt/conda/lib\")" | sudo tee -a /opt/julia/etc/julia/startup.jl \
  && echo "DEPOT_PATH[1]=\"/opt/julia/pkg\""                            | sudo tee -a /opt/julia/etc/julia/startup.jl ;
  type julia && echo "@ Version of Julia: $(julia --version)" || return 1 ;
}


setup_lua_base() {
     local VER_LUA_REQ="${1:-}" && VER_LUA_REQ="${VER_LUA_REQ#v}" \
  && local LUA_HOME="${LUA_HOME:-/opt/lua}" \
  && local VERS_JSON=$(curl_fsSL "https://api.github.com/repos/lua/lua/releases?per_page=50") \
  && local VERS_LUA=$(printf '%s\n' "$VERS_JSON" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\([0-9][0-9.]*\)".*/\1/p') \
  && if [ -n "$VER_LUA_REQ" ]; then
        local VER_LUA=$(printf '%s\n' "$VERS_LUA" | grep -F -x "$VER_LUA_REQ" | sed -n '1p')
       [ -n "$VER_LUA" ] || { echo "Lua version not found: $VER_LUA_REQ" >&2; exit 1; }
     else
       local VER_LUA=$(printf '%s\n' "$VERS_LUA" | sed -n '1p')
     fi \
  && { [ -n "$VER_LUA" ] || { echo "No Lua release found" >&2; exit 1; }; } \
  && local URL_LUA="https://www.lua.org/ftp/lua-${VER_LUA}.tar.gz" \
  && echo "Downloading Lua ${VER_LUA} from ${URL_LUA}" \
  && install_tar_gz "$URL_LUA" \
  && (cd "/opt/lua-${VER_LUA}" && sudo make linux test && sudo make install "INSTALL_TOP=$LUA_HOME") \
  && sudo ln -sf "$LUA_HOME"/bin/lua* /usr/bin/ \
  && sudo rm -rf "/opt/lua-${VER_LUA}" || exit 1 ;
  type lua && echo "@ Version of Lua installed: $(lua -v)" || exit 1;
}

setup_lua_rocks() {
 ## https://github.com/luarocks/luarocks/wiki/Installation-instructions-for-Unix
    local UNAME=$(uname | tr '[:upper:]' '[:lower:]') \
 && local VER_LUA_ROCKS_REQ="${1:-}" \
 && local VERS_LUA_ROCKS=$(curl_fsSL "https://luarocks.github.io/luarocks/releases/" | grep "${UNAME}" | grep -viE '(alpha|beta|rc)' | grep -Po '\d+\.\d+(\.\d+)?' | sort -rV) \
 && if [ -n "${VER_LUA_ROCKS_REQ}" ]; then
      local VER_LUA_ROCKS_RE=${VER_LUA_ROCKS_REQ#v} \
      && VER_LUA_ROCKS_RE=$(printf '%s' "$VER_LUA_ROCKS_RE" | sed 's/[.]/\\./g') \
      && local VER_LUA_ROCKS=$(echo "${VERS_LUA_ROCKS}" | grep -m1 -E "^${VER_LUA_ROCKS_RE}([.-]|$)")
    else
      local VER_LUA_ROCKS=$(echo "${VERS_LUA_ROCKS}" | head -1)
    fi \
 && [ -n "${VER_LUA_ROCKS}" ] \
 && local URL_LUA_ROCKS="https://luarocks.org/releases/luarocks-${VER_LUA_ROCKS}.tar.gz" \
 && echo "Downloading luarocks ${VER_LUA_ROCKS} from ${URL_LUA_ROCKS}" \
 && install_tar_gz "$URL_LUA_ROCKS" \
 && sudo mv /opt/luarocks-* /tmp/luarocks && cd /tmp/luarocks \
 && sudo ./configure --prefix=${LUA_HOME:-"/opt/lua"} --with-lua-include=${LUA_HOME:-"/opt/lua"}/include && sudo make install \
 && sudo ln -sf /opt/lua/bin/lua* /usr/bin/ \
 && rm -rf /tmp/luarocks ;
 type luarocks && echo "@ Version of luarocks: $(luarocks --version)" || return 1 ;
}


setup_bazel() {
     local UNAME=$(uname | tr '[:upper:]' '[:lower:]') \
  && local ARCH=$(uname -m | sed -e 's/aarch64/arm64/') \
  && local VER_BAZEL_REQ="${1:-}" \
  && local VERS_BAZEL=$(curl_fsSL "https://api.github.com/repos/bazelbuild/bazel/releases?per_page=50" | grep -Po '(?<="tag_name": ")[^"]+' | grep -vi 'rc' | grep -Po '\d[\d.]+' | sort -rV) \
  && if [ -n "${VER_BAZEL_REQ}" ]; then
       local VER_BAZEL_RE=${VER_BAZEL_REQ#v} \
       && VER_BAZEL_RE=$(printf '%s' "$VER_BAZEL_RE" | sed 's/[.]/\\./g') \
       && local VER_BAZEL=$(echo "${VERS_BAZEL}" | grep -m1 -E "^${VER_BAZEL_RE}([.-]|$)")
     else
       local VER_BAZEL=$(echo "${VERS_BAZEL}" | head -1)
     fi \
  && [ -n "${VER_BAZEL}" ] \
  && local URL_BAZEL="https://github.com/bazelbuild/bazel/releases/download/${VER_BAZEL}/bazel-${VER_BAZEL}-installer-${UNAME}-${ARCH}.sh" \
  && curl_fsSL -o /tmp/bazel.sh "${URL_BAZEL}" && chmod +x /tmp/bazel.sh \
  && sudo /tmp/bazel.sh && rm /tmp/bazel.sh ;
  type bazel && echo "@ Version of bazel: $(bazel --version)" || return 1 ;
}


setup_gradle() {
     local VER_GRADLE_REQ="${1:-}" \
  && local VERS_GRADLE=$(curl_fsSL "https://api.github.com/repos/gradle/gradle/releases?per_page=50" | grep -Po '(?<="tag_name": ")[^"]+' | grep -v 'M' | grep -vi 'rc' | grep -Po '\d[\d.]+' | sort -rV) \
  && if [ -n "${VER_GRADLE_REQ}" ]; then
       local VER_GRADLE_RE=${VER_GRADLE_REQ#v} \
       && VER_GRADLE_RE=$(printf '%s' "$VER_GRADLE_RE" | sed 's/[.]/\\./g') \
       && local VER_GRADLE=$(echo "${VERS_GRADLE}" | grep -m1 -E "^${VER_GRADLE_RE}([.-]|$)")
     else
       local VER_GRADLE=$(echo "${VERS_GRADLE}" | head -1)
     fi \
  && [ -n "${VER_GRADLE}" ] \
  && local URL_GRADLE="https://downloads.gradle.org/distributions/gradle-${VER_GRADLE}-bin.zip" \
  && sudo mv /opt/gradle* /opt/gradle \
  && sudo ln -sf /opt/gradle/bin/gradle /usr/bin ;
  type gradle && echo "@ Version of gradle: $(gradle --version)" || return 1 ;
}


setup_yq() {
  local ARCH=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/' -e 's/armv7l/arm/') ;
  case "$ARCH" in amd64|arm64|arm) ;; *) echo "Unsupported architecture for yq: $(uname -m)"; return 1 ;; esac
     local VER_YQ="" VER_YQ_REQ="${1:-}" \
  && local VERS_YQ=$(curl_fsSL "https://api.github.com/repos/mikefarah/yq/releases?per_page=50" | grep -Po '(?<="tag_name": ")[^"]+' | grep -Po 'v\K[\d.]+' | sort -rV) \
  && if [ -n "${VER_YQ_REQ}" ]; then
       local VER_YQ_RE=${VER_YQ_REQ#v} && VER_YQ_RE=$(printf '%s' "$VER_YQ_RE" | sed 's/[.]/\\./g') \
       && VER_YQ=$(echo "${VERS_YQ}" | grep -m1 -E "^${VER_YQ_RE}([.-]|$)")
     else
       VER_YQ=$(echo "${VERS_YQ}" | head -1)
     fi \
  && [ -n "${VER_YQ}" ] \
  && local URL_YQ="https://github.com/mikefarah/yq/releases/download/v${VER_YQ}/yq_linux_${ARCH}" \
  && echo "Installing yq v${VER_YQ} for arch ${ARCH} from: ${URL_YQ}" \
  && curl_fsSL -o /tmp/yq "${URL_YQ}" \
  && sudo install -m 0755 -D /tmp/yq /opt/bin/yq \
  && sudo ln -sf /opt/bin/yq /usr/bin/yq \
  && rm -f /tmp/yq ;
  type yq && echo "@ Installed yq: $(yq --version)" ;
}
