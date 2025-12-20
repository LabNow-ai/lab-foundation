# shell util functions

# function to debug, resolve package names from a text file and display.
install_echo()    { cat $1 | cut -d "%" -f 1 | sed '/^$/d' | xargs -r -n1 printf '%s\n' ; }

# function to install apt-get packages from a text file which lists package names (add comments with % char)
install_apt()     { apt-get -qq update -yq --fix-missing && apt-get -qq install -yq --no-install-recommends $(cat "$1" | cut -d '%' -f 1) ; }

# function to install conda packages from a text file which lists package names (add comments with % char)
install_conda()   { cat $1 | cut -d "%" -f 1 | sed '/^$/d' | xargs -r -n1 conda install -yq ; }
install_mamba()   { cat $1 | cut -d "%" -f 1 | sed '/^$/d' | xargs -r -n1 mamba install -yq --root-prefix="${CONDA_PREFIX}" --prefix="${CONDA_PREFIX}" ; }

# function to install python packages with pip from a text file which lists package names (add comments with % char)
install_pip()     { cat $1 | cut -d "%" -f 1 | sed '/^$/d' | xargs -r -n1 pip install --no-cache-dir --root-user-action=ignore -U --pre ; }

# function to install R packages from a text file which lists package names (add comments with % char, use quiet=T to be less verbose)
install_R()       { R -e "options(Ncpus=4);lapply(scan('$1','c',comment.char='%'),function(x){cat(x,system.time(install.packages(x,clean=T,quiet=T)),'\n')})"; }

# function to install go packages with go from a text file which lists package names (add comments with % char)
install_go()      { cat $1 | cut -d "%" -f 1 | sed '/^$/d' | xargs -r -n1 go get -u ; }

# function to install julia packages from a text file which lists package names (add comments with % char)
install_julia()   { julia -e "import Pkg; l=filter(x->length(x)>0, [split(i,r\"%| |\t\")[1] for i in readlines(\"$1\")]); Pkg.add(l)" ; }

# function to install octave packages with go from a text file which lists package names (add comments with % char)
install_octave()  { cat $1 | cut -d "%" -f 1 | sed '/^$/d' | xargs -r -n1 -I {} sh -c 'octave --eval "pkg install -forge {}"' ; }

# function to download a ZIP file and unzip it to /opt/
install_zip()     { curl -o /tmp/TMP.zip -sL $1 && unzip -q -d /opt/ /tmp/TMP.zip && rm /tmp/TMP.zip ; }

# function to download a .tar.gz file and unzip it to /opt/, add a second argument to extract only those file
install_tar_gz()  { curl -o /tmp/TMP.tgz -sL $1 && tar -C /opt/ -xzf /tmp/TMP.tgz ${2:-} && rm /tmp/TMP.tgz ; }

# function to download a .tar.bz file and unzip it to /opt/, add a second argument to extract only those file
install_tar_bz()  { curl -o /tmp/TMP.tbz -sL $1 && tar -C /opt/ -xjf /tmp/TMP.tbz ${2:-} && rm /tmp/TMP.tbz ; }

# function to download a .tar.xz file and unzip it to /opt/, add a second argument to extract only those file
install_tar_xz()  { curl -o /tmp/TMP.txz -sL $1 && tar -C /opt/ -xJf /tmp/TMP.txz ${2:-} && rm /tmp/TMP.txz ; }

# function to install java packages from a text file which lists JAR file maven full names (add comments with % char)
install_mvn() { cat $1 | cut -d "%" -f 1 | xargs -r -n1 -I {} mvn dependency:copy -DlocalRepositoryDirectory="/tmp/m2repo" -Djavax.net.ssl.trustStorePassword=changeit -Dartifact="{}" -DoutputDirectory="${2:-}" ; }

# function to clean up
install__clean(){
  which apt-get && apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/*
  which mamba   && mamba clean -ya && rm -rf ~/micromamba
  which conda   && conda clean -ya && ( rm -rf "${CONDA_PREFIX:-/opt/conda}"/pkgs/* || true )
  find "${CONDA_PREFIX:-/opt/conda}"/lib | grep -E "(__pycache__|\.pyc|\.pyo$)" | xargs rm -rf
  which npm     && npm cache clean --force
  ( rm -rf /tmp/.* /tmp/* /var/log/* /var/cache/* /root/.cache /root/.* || true )
  ( rm -rf /usr/share/doc /usr/share/man || true )
  chmod ugo+rwXt /tmp
  ls -alh /root /tmp
  echo "@ System release info:" && cat /etc/*release*
  echo "@ System environment variables:" && printenv | sort
  echo "@ Version of image: building finished at:" $(date)
  true
}

# function to list installed packages
list_installed_packages() {
  type pip    && echo "@ Version of Python and packages:" && python --version && pip list
  type conda  && echo "@ Version of Conda and packages:"  && conda info && conda list | grep -v "<pip>"
  type mamba  && echo "@ Version of Mamba and packages:"  && mamba info && mamba list | grep -v "<pip>"
  type node   && echo "@ Version of NodeJS and packages:" && node --version && npm --version && npm list -g --depth 0
  type java   && echo "@ Version of Java (JRE):"   && java  -version
  type javac  && echo "@ Version of Java (JDK):"   && javac -version
  type R      && echo "@ Version of R and libraries:"     && R --version && R -e "R.Version()\$version.string;installed.packages()[,c(3,10)]"
  type julia  && echo "@ Version of Julia and packages"   && julia --version && julia -e "using Pkg; for(k,v) in Pkg.dependencies(); println(v.name,\"==\",v.version); end"
  type go     && echo "@ Version of golang and packages:" && go version && go list ...
  type octave && echo "@ Version of Octave and packages:" && octave --version && octave --eval "pkg list"
  true
}

fix_permission() {
  GROUP_ID=${1:-0}; shift 1;
  for d in "$@"; do
      find "${d}" \
          ! \( \
              -group "${GROUP_ID}" \
              -a -perm -g+rwX \
          \) \
          -exec chgrp "${GROUP_ID}" -- {} \+ \
          -exec chmod g+rwX -- {} \+
      # setuid, setgid *on directories only*
      find "${d}" \
          \( \
              -type d \
              -a ! -perm -6000 \
          \) \
          -exec chmod +6000 -- {} \+;
  done
}
