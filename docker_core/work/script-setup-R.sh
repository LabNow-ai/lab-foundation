setup_R_datascience() {
     apt-get -qq update -yq --fix-missing \
  && apt-get -qq install -yq --no-install-recommends $(cat /opt/utils/install_list_R_datascience.apt | cut -d '%' -f 1) ;

  R -e "options(Ncpus=4);lapply(scan('/opt/utils/install_list_R_datascience.R','c',comment.char='%'),function(x){cat(x,system.time(install.packages(x,clean=T,quiet=T)),'\n')})";
}
