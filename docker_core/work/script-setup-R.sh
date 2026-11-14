setup_R_datascience() {
     sudo apt-get -qq update -yq --fix-missing \
  && sudo apt-get -qq install -yq --no-install-recommends $(cut -d '%' -f 1 /opt/utils/install_list_R_datascience.apt) ;

  sudo R -e "options(Ncpus=4);lapply(scan('/opt/utils/install_list_R_datascience.R','c',comment.char='%'),function(x){cat(x,system.time(install.packages(x,clean=T,quiet=T)),'\n')})";
}
