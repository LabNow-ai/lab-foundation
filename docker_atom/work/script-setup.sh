source /opt/utils/script-utils.sh


setup_mamba() {
  # Notice: mamba use $CONDA_PREFIX to locate base env
     UNAME=$(uname | tr '[:upper:]' '[:lower:]') && VER_MICROMAMBA="latest" \
  && ARCH=$(uname -m | sed -e 's/x86_64/64/') \
  && URL_MICROMAMBA="https://micromamba.snakepit.net/api/micromamba/${UNAME}-${ARCH}/${VER_MICROMAMBA}" \
  && echo "Downloading micromamba from ${URL_MICROMAMBA}" \
  && mkdir -pv /opt/mamba /etc/conda \
  && install_tar_bz $URL_MICROMAMBA bin/micromamba && mv /opt/bin/micromamba /opt/mamba/mamba \
  && ln -sf /opt/mamba/mamba /usr/bin/ \
  && touch /etc/conda/.condarc && ln -sf /etc/conda/.condarc /opt/conda/.condarc \
  && printf "channels:\n"       | sudo tee -a /etc/conda/.condarc \
  && printf "  - conda-forge\n" | sudo tee -a /etc/conda/.condarc \
  && cat /etc/conda/.condarc ;
  
  type mamba && echo "@ Version of mamba: $(mamba info)" || return -1 ;
}


setup_conda_postprocess() {
  type conda || return -1 ;

  # If python exists, set pypi source
  if [ -f "$(which python)" ]; then
    cat >/etc/pip.conf <<EOF
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
  ln -sf "${CONDA_PREFIX}/bin/conda" /usr/bin/

     conda config --system --prepend channels conda-forge \
  && conda config --system --set auto_update_conda false  \
  && conda config --system --set show_channel_urls true   \
  && conda config --system --set report_errors false \
  && conda config --system --set channel_priority strict \
  && conda update --all --quiet --yes ;

  # remove non-necessary folder/symlink "python3.1" exists
  rm -rf "${CONDA_PREFIX}"/bin/python3.1 "${CONDA_PREFIX}"/lib/python3.1 ;

  # These conda pkgs shouldn't be removed (otherwise will cause RemoveError) since they are directly required by conda: pip setuptools pycosat pyopenssl requests ruamel_yaml
  #    CONDA_PY_PKGS=$(conda list | grep "py3" | cut -d " " -f 1 | sed "/#/d;/conda/d;/pip/d;/setuptools/d;/pycosat/d;/pyopenssl/d;/requests/d;/ruamel_yaml/d;") \
  # && conda remove --force -yq "${CONDA_PY_PKGS}" \
  # && pip install -UIq pip setuptools "${CONDA_PY_PKGS}" \
  # && rm -rf "${CONDA_PREFIX}"/pkgs/*

  # Print Conda and Python packages information in the docker build log
  echo "@ Version of Conda & Python:" && conda info && conda list | grep -v "<pip>" ;
}

setup_conda_with_mamba() {
     local VERSION_PYTHON=${1:-"3.12"} \
  && local PREFIX="${CONDA_PREFIX:-/opt/conda}" \
  && mkdir -pv "${PREFIX}" \
  && mamba install -y --root-prefix="${PREFIX}" --prefix="${PREFIX}" -c "conda-forge" conda pip python="${VERSION_PYTHON}" \
  && setup_conda_postprocess ;
}

setup_conda_download() {
  ## https://docs.conda.io/projects/miniconda/en/latest/index.html
     local URL_CONDA="https://repo.continuum.io/miniconda/Miniconda3-latest-$(uname)-$(arch).sh" \
  && curl -sL "$URL_CONDA" -o /tmp/conda.sh \
  && mkdir -pv "${CONDA_PREFIX}" && bash /tmp/conda.sh -f -b -p "${CONDA_PREFIX}/" \
  && rm -rf /tmp/conda.sh \
  && setup_conda_postprocess ;
}

setup_nvtop() {
  ## The compiliation requries CMake 3.18 or higher, while the default version in CUDA 11.2 images is 3.16.3
     curl -sL https://apt.kitware.com/keys/kitware-archive-latest.asc | sudo gpg --dearmor -o /usr/share/keyrings/kitware-archive-keyring.gpg \
  && echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/kitware.list \
  && apt-get -qq update -yq --fix-missing && apt-get -qq install -yq --no-install-recommends cmake ;

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
  
  type nvtop && echo "Version of nvtop: $(nvtop --version)" || return -1 ;
}


setup_java_base() {
  ## Use the first arg and then VERSION_JDK to specify JDK major version. If not specified, will try the latest.
  ## for JDK>20 （25, 21）, install oracle version, for ealier version (17, 11 ,8), install adoptium version.
  ## Reason: for JDK 21 and 23, there are some issues with adoptium distribution (e.g. no alpine version for JDK 23, and no linux/arm64 version for JDK 21), while oracle distribution works fine.
  ## For JDK 17, 11 and 8, both distributions are fine, but we prefer adoptium since it's more lightweight without extra tools (e.g. mission control) and also has alpine version.

     local VER_JDK_MAJOR="${1:-${VERSION_JDK:-latest}}" \
  && local ARCH=$(uname -m | sed -e 's/x86_64/x64/') \
  && local IS_ALPINE=$(grep -q 'ID=alpine' /etc/os-release && echo true || echo false) \
  && echo "Installing JDK ${ARCH} of specified major version: ${VER_JDK_MAJOR}" ;
  
  local VER_JDK="$VER_JDK_MAJOR" ;
  if [[ "$VER_JDK_MAJOR" == "latest" ]] || { [[ "$VER_JDK_MAJOR" =~ ^[0-9]+$ ]] && [ "$VER_JDK_MAJOR" -gt 20 ]; }; then
    PAGE_JDK_DOWNLOAD="https://www.oracle.com/java/technologies/downloads/"
    PAGE_JDK=$(curl -sL --fail "$PAGE_JDK_DOWNLOAD" || { echo "Failed to fetch Oracle JDK download page" && return 1; } )

    if [[ "$VER_JDK_MAJOR" == "latest" ]]; then
      VER_JDK=$(echo "$PAGE_JDK" | grep -oE 'jdk-[0-9]+' | sed 's/jdk-//' | sort -rV | head -1) ;  
    fi ;

       URL_JDK_DOWNLOAD=$(echo "${PAGE_JDK}" | grep "tar.gz" | grep "http" | grep -v sha256 | grep ${ARCH} | grep -i $(uname) | grep -oP "(https?://[^\s<>\'\"]*)" | grep "jdk-${VER_JDK}" | head -n 1) \
    && VER_JDK_MINOR=$(echo $URL_JDK_DOWNLOAD | grep -Po '[\d\.]{3,}' | head -n1) ;
  else
       URL_JDK_adoptium="https://api.github.com/repos/adoptium/temurin${VER_JDK_MAJOR}-binaries/releases/latest" \
    && URL_JDK_DOWNLOAD=$(
      curl -sL $URL_JDK_adoptium | grep 'tar.gz' | grep -vE '.sha256|.sig|.json|debug|test' | grep ${ARCH} | grep -i $(uname) \
      | grep -oP "(https?://[^\s<>\'\"]*)" | grep -E $(if [ "$IS_ALPINE" = true ]; then echo 'alpine'; else echo -v 'alpine'; fi) | head -n1
    ) ;
  fi

  echo "Installing JDK version ${VER_JDK} from: ${URL_JDK_DOWNLOAD}" ;
  install_tar_gz "${URL_JDK_DOWNLOAD}" && mv /opt/jdk* /opt/jdk && ln -sf /opt/jdk/bin/* /usr/bin/ ;

  type java  && echo "@ Version of Java (java):  $(java -version)"  || return -1 ;
  type javac && echo "@ Version of Java (javac): $(javac -version)" || return -1 ;
}


setup_java_maven() {
     local VER_MAVEN_MAJOR="${1-3}" \
  && local ATOM_MAVEN=$(curl -sL https://maven.apache.org/docs/history.html | grep '/ref/') \
  && local VERS_MAVEN=$(echo "${ATOM_MAVEN}" | grep -oP '(?<=/ref/)[0-9]+\.[0-9]+(\.[0-9]+)?(-[a-z]+-[0-9]+)?(?=/)' | sort -r) \
  && if [ -n "${VER_MAVEN_MAJOR}" ]; then
       local VER_MAVEN=$(echo "${VERS_MAVEN}" | grep -E "^${VER_MAVEN_MAJOR}\\." | sort -rV | head -1)
     else
       local VER_MAVEN=$(echo "${VERS_MAVEN}" | sort -rV | head -1)
     fi \
  && local URL_MAVEN="http://archive.apache.org/dist/maven/maven-3/${VER_MAVEN}/binaries/apache-maven-${VER_MAVEN}-bin.zip" \
  && echo "Downloading Maven version ${VER_MAVEN} from: ${URL_MAVEN}" \
  && install_zip "${URL_MAVEN}" \
  && mv "/opt/apache-maven-${VER_MAVEN}" /opt/maven \
  && ln -sf /opt/maven/bin/mvn* /usr/bin/ ;

  type mvn && echo "@ Version of Maven: $(mvn --version)" || return -1 ;
}


setup_node_base() {
     local VER_NODEJS_MAJOR="${1-}" \
  && local UNAME=$(uname | tr '[:upper:]' '[:lower:]') \
  && local ARCH=$(uname -m | sed -e 's/x86_64/x64/' -e 's/aarch64/arm64/') \
  && local ATOM_NODEJS=$(curl -sL https://github.com/nodejs/node/releases.atom | grep 'releases/tag' | sort -r) \
  && if [ -n "${VER_NODEJS_MAJOR}" ]; then
       local VER_NODEJS=$(echo "${ATOM_NODEJS}" | grep -Po '\d[.\d]+' | grep -E "^${VER_NODEJS_MAJOR}\\." | head -1)
     else
       local VER_NODEJS=$(echo "${ATOM_NODEJS}" | head -1 | grep -Po '\d[.\d]+')
       local VER_NODEJS_MAJOR=$(echo "${VER_NODEJS}" | cut -d '.' -f1)
     fi \
  && local URL_NODEJS="https://nodejs.org/download/release/latest-v${VER_NODEJS_MAJOR}.x/node-v${VER_NODEJS}-${UNAME}-${ARCH}.tar.gz" \
  && echo "Downloading NodeJS version ${VER_NODEJS} from: ${URL_NODEJS}" \
  && install_tar_gz ${URL_NODEJS} \
  && mv /opt/node* /opt/node \
  && ln -sf /opt/node/bin/n* /usr/bin/ \
  && echo 'export PATH=${PATH}:/opt/node/bin' | sudo tee -a /etc/profile.d/path-node.sh \
  && source /etc/profile.d/path-node.sh \
  && npm install -g npm ;
  # cd /tmp && corepack enable && yarn set version stable && echo "@ Version of Yarn: $(yarn -v)"
  type node && echo "@ Version of Node and node: $(node -v)" || return -1 ;
  type npm  && echo "@ Version of Node and npm:  $(npm -v)"  || return -1 ;
}

setup_node_pnpm() {
     local VER_PNPM_MAJOR="${1-}" \
  && local UNAME=$(uname | tr '[:upper:]' '[:lower:]') \
  && local ARCH=$(uname -m | sed -e 's/x86_64/x64/' -e 's/aarch64/arm64/') \
  && local ATOM_PNPM=$(curl -sL https://github.com/pnpm/pnpm/releases.atom | grep 'releases/tag' | grep -v 'alpha' | sort -r) \
  && if [ -n "${VER_PNPM_MAJOR}" ]; then
       local VER_PNPM=$(echo "${ATOM_PNPM}" | grep -Po '\d[\d.]+' | grep -E "^${VER_PNPM_MAJOR}\\." | head -1)
     else
       local VER_PNPM=$(echo "${ATOM_PNPM}" | head -1 | grep -Po '\d[\d.]+')
     fi \
  && local URL_PNPM="https://github.com/pnpm/pnpm/releases/download/v${VER_PNPM}/pnpm-${UNAME}-${ARCH}" \
  && echo "Downloading pnpm version ${VER_PNPM} from: ${URL_PNPM}" \
  && curl -L "${URL_PNPM}" -o /usr/local/bin/pnpm \
  && sudo chmod +x /usr/local/bin/pnpm \
  && echo 'export PNPM_STORE_PATH=/opt/node/pnpm-store' | sudo tee -a /etc/profile.d/path-pnpm.sh \
  && echo 'export PNPM_HOME="/opt/node/pnpm"' | sudo tee -a /etc/profile.d/path-pnpm.sh \
  && echo 'export PATH=$PATH:$PNPM_HOME'      | sudo tee -a /etc/profile.d/path-pnpm.sh \
  && source /etc/profile.d/path-pnpm.sh ;

  type pnpm && echo "@ Version of pnpm: $(pnpm --version)" || return -1 ;
}

setup_node_bun() {
     local VER_BUN_MAJOR="${1-}" \
  && local UNAME=$(uname | tr '[:upper:]' '[:lower:]') \
  && local ARCH=$(uname -m | sed -e 's/x86_64/x64/' ) \
  && local ATOM_BUN=$(curl -sL https://github.com/oven-sh/bun/releases.atom | grep 'releases/tag' | sort -r) \
  && if [ -n "${VER_BUN_MAJOR}" ]; then
       local VER_BUN=$(echo "${ATOM_BUN}" | grep -Po 'bun-v\K\d+\.\d+\.\d+' | grep -E "^${VER_BUN_MAJOR}\\." | head -1)
     else
       local VER_BUN=$(echo "${ATOM_BUN}" | head -1 | grep -Po 'bun-v\K\d+\.\d+\.\d+')
     fi \
  && local URL_BUN="https://github.com/oven-sh/bun/releases/download/bun-v${VER_BUN}/bun-${UNAME}-${ARCH}.zip" \
  && echo "Downloading bun version ${VER_BUN} from: ${URL_BUN}" \
  && install_zip "${URL_BUN}" \
  && sudo mv /opt/bun-* /opt/bun \
  && sudo ln -sf /opt/bun/bun /usr/bin/ \
  && echo 'export PATH="${PATH}:/opt/bun"' | sudo tee -a /etc/profile.d/path-bun.sh \
  && source /etc/profile.d/path-bun.sh ;

  type bun && echo "@ Version of bun: $(bun -v)" || return $? ;
}


setup_GO() {
     local VER_GO_MAJOR="${1-}" \
  && local UNAME=$(uname | tr '[:upper:]' '[:lower:]') \
  && local ARCH=$(dpkg --print-architecture) \
  && local ATOM_GO=$(curl -sL https://github.com/golang/go/releases.atom | grep 'releases/tag' | grep -v 'rc' | sort -r ) \
  && if [ -n "${VER_GO_MAJOR}" ]; then
       local VER_GO=$(echo "${ATOM_GO}" | grep -Po '\d[\d.]+' | grep -E "^${VER_GO_MAJOR}\\." | head -1)
     else
       local VER_GO=$(echo "${ATOM_GO}" | head -1 | grep -Po '\d[\d.]+')
     fi \
  && local URL_GO="https://dl.google.com/go/go${VER_GO}.${UNAME}-${ARCH}.tar.gz" \
  && echo "Downloading golang version ${VER_GO} from: ${URL_GO}" \
  && install_tar_gz "${URL_GO}" go \
  && sudo ln -sf /opt/go/bin/go* /usr/bin/ \
  && echo 'export GOROOT="/opt/go"'       | sudo tee -a /etc/profile.d/path-go.sh \
  && echo 'export GOBIN="$GOROOT/bin"'    | sudo tee -a /etc/profile.d/path-go.sh \
  && echo 'export GOPATH="$GOROOT/path"'  | sudo tee -a /etc/profile.d/path-go.sh \
  && echo 'export PATH=$PATH:$GOROOT/bin:$GOPATH/bin' | sudo tee -a /etc/profile.d/path-go.sh \
  && source /etc/profile.d/path-go.sh ;
  
  type go && echo "@ Version of golang: $(go version)" || return -1 ;
}


setup_rust() {
  curl -sSf https://sh.rustup.rs | sudo sh -c '
    export CARGO_HOME=/opt/cargo && export RUSTUP_HOME=/opt/rust
    sh -s -- -y --no-modify-path --profile minimal --default-toolchain stable
  '
     echo 'export CARGO_HOME="/opt/cargo"'     | sudo tee -a /etc/profile.d/path-rust.sh > /dev/null \
  && echo 'export RUSTUP_HOME="/opt/rust"'     | sudo tee -a /etc/profile.d/path-rust.sh > /dev/null \
  && echo 'export PATH="$PATH:/opt/cargo/bin"' | sudo tee -a /etc/profile.d/path-rust.sh > /dev/null \
  && source /etc/profile.d/path-rust.sh ;

  type rustup && echo "@ Version of rustup: $(rustup --version)" || return -1 ;
  type rustc  && echo "@ Version of rustc:  $(rustc  --version)" || return -1 ;
}


setup_R_base() {
     local UNAME=$(uname | tr '[:upper:]' '[:lower:]') \
  && curl -sL https://cloud.r-project.org/bin/${UNAME}/ubuntu/marutter_pubkey.asc | sudo tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc \
  && echo "deb https://cloud.r-project.org/bin/${UNAME}/ubuntu $(lsb_release -cs)-cran40/" > /etc/apt/sources.list.d/cran.list \
  && install_apt  /opt/utils/install_list_R_base.apt \
  && echo "options(repos=structure(c(CRAN=\"https://cloud.r-project.org\")))" | sudo tee -a /etc/R/Rprofile.site \
  && R -e "install.packages(c('devtools'),clean=T,quiet=T);" \
  && R -e "install.packages(c('devtools'),clean=T,quiet=F);" \
  && ( type java && type R && R CMD javareconf || true ) ;
  
  type R && echo "@ Version of R: $(R --version)" || return -1 ;
}


setup_julia() {
     local VER_JULIA_MAJOR="${1-}" \
  && local UNAME=$(uname | tr '[:upper:]' '[:lower:]') \
  && local ARCH_1=$(uname -m) \
  && local ARCH_2=$(uname -m | sed -e 's/x86_64/x64/') \
  && local ATOM_JULIA=$(curl -sL https://github.com/JuliaLang/julia/releases.atom | grep -P 'releases/tag(?!.*(rc|alpha|beta))' | sort -r) \
  && if [ -n "${VER_JULIA_MAJOR}" ]; then
       local VER_JULIA=$(echo "${ATOM_JULIA}" | grep -Po '\d[\d.]+' | grep -E "^${VER_JULIA_MAJOR}\\." | head -1)
     else
       local VER_JULIA=$(echo "${ATOM_JULIA}" | head -1 | grep -Po '\d[\d.]+')
     fi \
  && local VER_JULIA_MAJOR=$(echo "${VER_JULIA}" | cut -d '.' -f1,2 ) \
  && local URL_JULIA="https://julialang-s3.julialang.org/bin/linux/${ARCH_2}/${VER_JULIA_MAJOR}/julia-${VER_JULIA}-linux-${ARCH_1}.tar.gz" \
  && echo "Downloading Julia version ${VER_JULIA} from: ${URL_JULIA}" \
  && install_tar_gz $URL_JULIA \
  && sudo mv /opt/julia-* /opt/julia \
  && sudo ln -fs /opt/julia/bin/julia /usr/bin/julia \
  && sudo mkdir -pv /opt/julia/pkg \
  && echo "import Libdl; push!(Libdl.DL_LOAD_PATH, \"/opt/conda/lib\")" | sudo tee -a /opt/julia/etc/julia/startup.jl \
  && echo "DEPOT_PATH[1]=\"/opt/julia/pkg\""                            | sudo tee -a /opt/julia/etc/julia/startup.jl ;
  
  type julia && echo "@ Version of Julia: $(julia --version)" || return -1 ;
}


setup_lua_base() {
    local VER_LUA=$(curl -sL https://www.lua.org/download.html | grep "cd lua" | head -1 | grep -Po '(\d[\d|.]+)') \
 && local URL_LUA="http://www.lua.org/ftp/lua-${VER_LUA}.tar.gz" \
 && echo "Downloading LUA ${VER_LUA} from ${URL_LUA}" \
 && install_tar_gz $URL_LUA \
 && sudo mv /opt/lua-* /tmp/lua && cd /tmp/lua \
 && sudo make linux test && sudo make install INSTALL_TOP=${LUA_HOME:-"/opt/lua"} \
 && sudo ln -sf ${LUA_HOME:-"/opt/lua"}/bin/lua* /usr/bin/ \
 && rm -rf /tmp/lua ;

 type lua && echo "@ Version of LUA installed: $(lua -v)" || return -1 ;
}

setup_lua_rocks() {
 ## https://github.com/luarocks/luarocks/wiki/Installation-instructions-for-Unix
    local UNAME=$(uname | tr '[:upper:]' '[:lower:]') \
 && local VER_LUA_ROCKS=$(curl -sL https://luarocks.github.io/luarocks/releases/ | grep "${UNAME}" | head -1 | grep -Po '(\d[\d|.]+)' | head -1) \
 && local URL_LUA_ROCKS="https://luarocks.org/releases/luarocks-${VER_LUA_ROCKS}.tar.gz" \
 && echo "Downloading luarocks ${VER_LUA_ROCKS} from ${URL_LUA_ROCKS}" \
 && install_tar_gz $URL_LUA_ROCKS \
 && sudo mv /opt/luarocks-* /tmp/luarocks && cd /tmp/luarocks \
 && sudo ./configure --prefix=${LUA_HOME:-"/opt/lua"} --with-lua-include=${LUA_HOME:-"/opt/lua"}/include && sudo make install \
 && sudo ln -sf /opt/lua/bin/lua* /usr/bin/ \
 && rm -rf /tmp/luarocks ;

 type luarocks && echo "@ Version of luarocks: $(luarocks --version)" || return -1 ;
}


setup_bazel() {
     local UNAME=$(uname | tr '[:upper:]' '[:lower:]') \
  && local ARCH=$(uname -m | sed -e 's/aarch64/arm64/') \
  && local VER_BAZEL=$(curl -sL https://github.com/bazelbuild/bazel/releases.atom | grep 'releases/tag' | head -1 | grep -Po '\d[\d.]+' ) \
  && local URL_BAZEL="https://github.com/bazelbuild/bazel/releases/download/${VER_BAZEL}/bazel-${VER_BAZEL}-installer-${UNAME}-${ARCH}.sh" \
  && curl -o /tmp/bazel.sh -sL "${URL_BAZEL}" && chmod +x /tmp/bazel.sh \
  && /tmp/bazel.sh && rm /tmp/bazel.sh ;
  
  type bazel && echo "@ Version of bazel: $(bazel --version)" || return -1 ;
}


setup_gradle() {
     local VER_GRADLE=$(curl -sL https://github.com/gradle/gradle/releases.atom | grep 'releases/tag' | grep -v 'M' | head -1 | grep -Po '\d[\d.]+' ) \
  && local URL_GRADLE="https://downloads.gradle.org/distributions/gradle-${VER_GRADLE}-bin.zip" \
  && mv /opt/gradle* /opt/gradle \
  && ln -sf /opt/gradle/bin/gradle /usr/bin ;
  
  type gradle && echo "@ Version of gradle: $(gradle --version)" || return -1 ;
}


setup_yq() {
  local ARCH=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/' -e 's/armv7l/arm/') ;
  [[ "$ARCH" =~ ^(amd64|arm64|arm)$ ]] || { echo "Unsupported architecture for yq: $(uname -m)"; return 1; }
     local VER_YQ=$(curl -sL -o /dev/null -w "%{url_effective}" https://github.com/mikefarah/yq/releases/latest | grep -oP 'v\K[\d.]+') \
  && local URL_YQ="https://github.com/mikefarah/yq/releases/download/v${VER_YQ}/yq_linux_${ARCH}" \
  && echo "Installing yq v${VER_YQ} for arch ${ARCH} from: ${URL_YQ}" \
  && curl -fSL "${URL_YQ}" -o /tmp/yq \
  && install -m 0755 -D /tmp/yq /opt/bin/yq \
  && ln -sf /opt/bin/yq /usr/bin/yq \
  && rm -f /tmp/yq

  type yq && echo "@ Installed yq: $(yq --version)"
}
