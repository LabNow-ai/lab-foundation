source /opt/utils/script-utils.sh


setup_mamba() {
  # Notice: mamba use $CONDA_PREFIX to locate base env
     ARCH="linux-64" && MICROMAMBA_VERSION="latest" \
  && MAMBA_URL="https://micromamba.snakepit.net/api/micromamba/${ARCH}/${MICROMAMBA_VERSION}" \
  && mkdir -pv /opt/mamba /etc/conda \
  && install_tar_bz $MAMBA_URL bin/micromamba && mv /opt/bin/micromamba /opt/mamba/mamba \
  && ln -sf /opt/mamba/mamba /usr/bin/ \
  && touch /etc/conda/.condarc \
  && printf "channels:\n"       >> /etc/conda/.condarc \
  && printf "  - conda-forge\n" >> /etc/conda/.condarc ;
  
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

  echo 'export PATH=${PATH}:${CONDA_PREFIX:-"/opt/conda"}/bin'		>> /etc/profile.d/path-conda.sh
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
    VERSION_PYTHON=${1:-"3.12"}; shift 1;
     local PREFIX="${CONDA_PREFIX:-/opt/conda}" \
  && mkdir -pv "${PREFIX}" \
  && mamba install -y --root-prefix="${PREFIX}" --prefix="${PREFIX}" -c "conda-forge" conda pip python="${VERSION_PYTHON}" \
  && setup_conda_postprocess ;
}

setup_conda_download() {
  ## https://docs.conda.io/projects/miniconda/en/latest/index.html
     mkdir -pv "${CONDA_PREFIX}" \
  && wget -qO- "https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-$(arch).sh" -O /tmp/conda.sh \
  && bash /tmp/conda.sh -f -b -p "${CONDA_PREFIX}/" \
  && rm -rf /tmp/conda.sh \
  && setup_conda_postprocess ;
}

setup_nvtop() {
  ## The compiliation requries CMake 3.18 or higher. default version in CUDA 11.2 images is 3.16.3
     curl -sL https://apt.kitware.com/keys/kitware-archive-latest.asc | sudo tee /etc/apt/trusted.gpg.d/kitware.asc \
  && echo "deb https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/kitware.list \
  && apt-get -qq update -yq --fix-missing && apt-get -qq install -yq --no-install-recommends cmake ;

  # Install Utilities "nvtop" from source: libdrm-dev libsystemd-dev used by AMD/Intel GPU support, libudev-dev used by ubuntu18.04
     LIB_PATH=$(find / -name "libnvidia-ml*" 2>/dev/null) \
  && DIRECTORY=$(pwd) && cd /tmp \
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
  ## 23, 21(LTS); 17, 11, 8

  local VER_JDK=${VERSION_JDK:-"11"}
  ARCH="x64"
  IS_ALPINE=$(grep -q 'ID=alpine' /etc/os-release && echo true || echo false)

  echo "Use env var VERSION_JDK to specify JDK major version. If not specified, will install version 11 by default."
  echo "Will install JDK version ${VER_JDK}"

     PAGE_JDK_DOWNLOAD="https://www.oracle.com/java/technologies/downloads/" \
  && URL_JDK_ORCA=$(curl -sL $PAGE_JDK_DOWNLOAD | grep "tar.gz" | grep "http" | grep -v sha256 | grep ${ARCH} | grep -i $(uname) | grep -oP "(https?://[^\s<>\'\"]*)" | grep "jdk-${VER_JDK}" | head -n 1) \
  && VER_JDK_MINOR=$(echo $URL_JDK_ORCA | grep -Po '[\d\.]{3,}' | head -n1)

  if [ "$VER_JDK" -gt 20 ] ; then
    URL_JDK_DOWNLOAD=${URL_JDK_ORCA}
  else
       URL_JDK_adoptium="https://api.github.com/repos/adoptium/temurin${VER_JDK}-binaries/releases/latest" \
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
     VERSION_MAVEN=$(curl -sL https://maven.apache.org/download.cgi | grep 'latest' | head -1 | grep -Po '\d[\d.]+') \
  && install_zip "http://archive.apache.org/dist/maven/maven-3/${VERSION_MAVEN}/binaries/apache-maven-${VERSION_MAVEN}-bin.zip" \
  && mv "/opt/apache-maven-${VERSION_MAVEN}" /opt/maven \
  && ln -sf /opt/maven/bin/mvn* /usr/bin/ ;

  type mvn && echo "@ Version of Maven: $(mvn --version)" || return -1 ;
}


setup_node() {
     ARCH="x64" \
  && VER_NODEJS=$(curl -sL https://github.com/nodejs/node/releases.atom | grep 'releases/tag' | head -1 | grep -Po '\d[.\d]+') \
  && VER_NODEJS_MAJOR=$(echo "${VER_NODEJS}" | cut -d '.' -f1 ) \
  && NODEJS_URL="https://nodejs.org/download/release/latest-v${VER_NODEJS_MAJOR}.x/node-v${VER_NODEJS}-linux-${ARCH}.tar.gz" \
  && echo "Downloading NodeJS from: ${NODEJS_URL}" \
  && install_tar_gz ${NODEJS_URL} \
  && mv /opt/node* /opt/node \
  && ln -sf /opt/node/bin/n* /usr/bin/ \
  && echo 'export PATH=${PATH}:/opt/node/bin' >> /etc/profile.d/path-node.sh \
  && npm install -g npm ;
  # cd /tmp && corepack enable && yarn set version stable && echo "@ Version of Yarn: $(yarn -v)"
  type node && echo "@ Version of Node and node: $(node -v)" || return -1 ;
  type npm  && echo "@ Version of Node and npm:  $(npm -v)"  || return -1 ;
}


setup_GO() {
     VER_GO=$(curl -sL https://github.com/golang/go/releases.atom | grep 'releases/tag' | grep -v 'rc' | head -1 | grep -Po '\d[\d.]+') \
  && URL_GO="https://dl.google.com/go/go${VER_GO}.linux-$(dpkg --print-architecture).tar.gz" \
  && install_tar_gz "${URL_GO}" go \
  && ln -sf /opt/go/bin/go* /usr/bin/ \
  && echo 'export GOROOT="/opt/go"'       >> /etc/profile.d/path-go.sh \
  && echo 'export GOBIN="$GOROOT/bin"'    >> /etc/profile.d/path-go.sh \
  && echo 'export GOPATH="$GOROOT/path"'  >> /etc/profile.d/path-go.sh \
  && echo 'export PATH=$PATH:$GOROOT/bin:$GOPATH/bin' >> /etc/profile.d/path-go.sh ;
  
  type go && echo "@ Version of golang: $(go version)" || return -1 ;
}


setup_rust() {
     export CARGO_HOME=/opt/cargo \
  && export RUSTUP_HOME=/opt/rust \
  && export PATH=$PATH:${CARGO_HOME}/bin \
  && curl -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile minimal --default-toolchain stable \
  && echo 'export CARGO_HOME="/opt/cargo"'		>> /etc/profile.d/path-rust.sh \
  && echo 'export RUSTUP_HOME="/opt/rust"'		>> /etc/profile.d/path-rust.sh \
  && echo 'export PATH=$PATH:/opt/cargo/bin'	>> /etc/profile.d/path-rust.sh ;
  
  type rustup && echo "@ Version of rustup: $(rustup --version)" || return -1 ;
  type rustc  && echo "@ Version of rustc:  $(rustc  --version)" || return -1 ;
}


setup_R_base() {
     curl -sL https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | sudo tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc \
  && echo "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/" > /etc/apt/sources.list.d/cran.list \
  && install_apt  /opt/utils/install_list_R_base.apt \
  && echo "options(repos=structure(c(CRAN=\"https://cloud.r-project.org\")))" >> /etc/R/Rprofile.site \
  && R -e "install.packages(c('devtools'),clean=T,quiet=T);" \
  && R -e "install.packages(c('devtools'),clean=T,quiet=F);" \
  && ( type java && type R && R CMD javareconf || true ) ;
  
  type R && echo "@ Version of R: $(R --version)" || return -1 ;
}


setup_julia() {
     JULIA_URL="https://julialangnightlies-s3.julialang.org/bin/linux/x64/julia-latest-linux64.tar.gz" \
  && install_tar_gz $JULIA_URL \
  && mv /opt/julia-* /opt/julia \
  && ln -fs /opt/julia/bin/julia /usr/bin/julia \
  && mkdir -p /opt/julia/pkg \
  && echo "import Libdl; push!(Libdl.DL_LOAD_PATH, \"/opt/conda/lib\")" >> /opt/julia/etc/julia/startup.jl \
  && echo "DEPOT_PATH[1]=\"/opt/julia/pkg\""                            >> /opt/julia/etc/julia/startup.jl ;
  
  type julia && echo "@ Version of Julia: $(julia --version)" || return -1 ;
}


setup_lua_base() {
    VERSION_LUA=$(curl -sL https://www.lua.org/download.html | grep "cd lua" | head -1 | grep -Po '(\d[\d|.]+)') \
 && URL_LUA="http://www.lua.org/ftp/lua-${VERSION_LUA}.tar.gz" \
 && echo "Downloading LUA ${VERSION_LUA} from ${URL_LUA}" \
 && install_tar_gz $URL_LUA \
 && mv /opt/lua-* /tmp/lua && cd /tmp/lua \
 && make linux test && make install INSTALL_TOP=${LUA_HOME:-"/opt/lua"} \
 && ln -sf ${LUA_HOME:-"/opt/lua"}/bin/lua* /usr/bin/ \
 && rm -rf /tmp/lua ;

 type lua && echo "@ Version of LUA installed: $(lua -v)" || return -1 ;
}

setup_lua_rocks() {
 ## https://github.com/luarocks/luarocks/wiki/Installation-instructions-for-Unix
    VERSION_LUA_ROCKS=$(curl -sL https://luarocks.github.io/luarocks/releases/ | grep "linux-x86_64" | head -1 | grep -Po '(\d[\d|.]+)' | head -1) \
 && URL_LUA_ROCKS="http://luarocks.github.io/luarocks/releases/luarocks-${VERSION_LUA_ROCKS}.tar.gz" \
 && echo "Downloading luarocks ${VERSION_LUA_ROCKS} from ${URL_LUA_ROCKS}" \
 && install_tar_gz $URL_LUA_ROCKS \
 && mv /opt/luarocks-* /tmp/luarocks && cd /tmp/luarocks \
 && ./configure --prefix=${LUA_HOME:-"/opt/lua"} --with-lua-include=${LUA_HOME:-"/opt/lua"}/include && make install \
 && ln -sf /opt/lua/bin/lua* /usr/bin/ \
 && rm -rf /tmp/luarocks ;

 type luarocks && echo "@ Version of luarocks: $(luarocks --version)" || return -1 ;
}

setup_traefik() {
     TRAEFIK_VERSION=$(curl -sL https://github.com/traefik/traefik/releases.atom | grep 'releases/tag' | head -1 | grep -Po '\d[\d.]+') \
  && TRAEFIK_URL="https://github.com/traefik/traefik/releases/download/v${TRAEFIK_VERSION}/traefik_v${TRAEFIK_VERSION}_linux_$(dpkg --print-architecture).tar.gz" \
  && install_tar_gz "${TRAEFIK_URL}" traefik \
  && ln -sf /opt/traefik /usr/bin/ ;
  
  type traefik && echo "@ Version of traefik: $(traefik version)" || return -1 ;
}


setup_bazel() {
     VER_BAZEL=$(curl -sL https://github.com/bazelbuild/bazel/releases.atom | grep 'releases/tag' | head -1 | grep -Po '\d[\d.]+' ) \
  && URL_BAZEL="https://github.com/bazelbuild/bazel/releases/download/${VER_BAZEL}/bazel-${VER_BAZEL}-installer-linux-x86_64.sh" \
  && curl -o /tmp/bazel.sh -sL "${URL_BAZEL}" && chmod +x /tmp/bazel.sh \
  && /tmp/bazel.sh && rm /tmp/bazel.sh ;
  
  type bazel && echo "@ Version of bazel: $(bazel --version)" || return -1 ;
}


setup_gradle() {
     VER_GRADLE=$(curl -sL https://github.com/gradle/gradle/releases.atom | grep 'releases/tag' | grep -v 'M' | head -1 | grep -Po '\d[\d.]+' ) \
  && install_zip "https://downloads.gradle.org/distributions/gradle-${VER_GRADLE}-bin.zip" \
  && mv /opt/gradle* /opt/gradle \
  && ln -sf /opt/gradle/bin/gradle /usr/bin ;
  
  type gradle && echo "@ Version of gradle: $(gradle --version)" || return -1 ;
}
