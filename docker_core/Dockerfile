# Distributed under the terms of the Modified BSD License.

ARG BASE_NAMESPACE
ARG BASE_IMG="base"
FROM ${BASE_NAMESPACE:+$BASE_NAMESPACE/}${BASE_IMG}

LABEL maintainer="postmaster@labnow.ai"

ARG ARG_PROFILE_NODEJS

# base,datascience,rstudio,rshiny
ARG ARG_PROFILE_R

# base,database,datascience,nlp,cv,bioinfo
ARG ARG_PROFILE_PYTHON
ARG ARG_PROFILE_GO
ARG ARG_PROFILE_JULIA
ARG ARG_PROFILE_RUST
ARG ARG_PROFILE_OCTAVE

# base,cjk
ARG ARG_PROFILE_LATEX

ARG ARG_PROFILE_JAVA
ARG VERSION_JDK

SHELL ["/bin/bash", "--login", "-o", "pipefail", "-c"]

COPY work /opt/utils/

RUN set -eux \
 && source /opt/utils/script-setup.sh \
 # -----------------------------
 && echo "NodeJS is required to build some components like JupyterLab Extensions later" \
 && for profile in $(echo $ARG_PROFILE_NODEJS | tr "," "\n") ; do ( setup_node_${profile} ) ; done \
 # -----------------------------
 && echo "If installing Java environment - notice that Java can be dependency for some other packages like rJava" \
 && export VERSION_JDK=${VERSION_JDK:-11} \
 && for profile in $(echo $ARG_PROFILE_JAVA | tr "," "\n") ; do ( setup_java_${profile} ) ; done \
 # -----------------------------
 && echo "If installing LaTex and LaTex CJK packages." \
 && for profile in $(echo $ARG_PROFILE_LATEX | tr "," "\n") ; do ( install_apt "/opt/utils/install_list_latex_${profile}.apt" ) ; done \
 # -----------------------------
 && echo "If installing R environment - put this after Java ready to configure rJava" \
 && source /opt/utils/script-setup-R.sh \
 && for profile in $(echo $ARG_PROFILE_R | tr "," "\n") ; do ( setup_R_${profile} ) ; done \
 && ( which R && ln -sf "${CONDA_PREFIX}"/bin/python3.* /usr/bin/ || true ) && ls -alh /usr/bin/python* \
 # -----------------------------
 && echo "If on a x86_64 architecture: 1) if mkl specified, install nomkl; 2) install conda packages as specified." \
 && if echo $(arch) | grep -q "x86_64" ; then \
    echo "mkl"   >> /opt/utils/install_list_core.conda && echo "Install mkl." ; \
  else \
    echo "nomkl" >> /opt/utils/install_list_core.conda && echo "Install nomkl." ; \
  fi \
  && ln -sf /opt/utils/install_list_core.conda /opt/utils/install_list_PY_mkl.pip \
  && install_mamba /opt/utils/install_list_core.conda \
 # -----------------------------
 && echo "If installing Python packages" \
 && ( $(grep -q "datascience" <<< "${ARG_PROFILE_PYTHON}") && ( \
         ( which R     && echo "rpy2  % Install rpy2 if R exists"    >> /opt/utils/install_list_PY_datascience.pip || echo "Skip rpy2 install" ) \
      && ( which java  && echo "py4j  % Install py4j if Java exists" >> /opt/utils/install_list_PY_datascience.pip || echo "Skip py4j install" ) \
    ) || echo "Skip Python datascience packages install" ) \
 # -----------------------------
 && export CUDA_VER=$(echo ${CUDA_VERSION:-"999"} | cut -c1-4 | sed 's/\.//' ) \
 && export IDX=$( [ -x "$(command -v nvcc)" ] && echo "cu${CUDA_VER:-117}" || echo "cpu" ) \
 && echo "Detected CUDA version=${CUDA_VER} and IDX=${IDX}" \
 # -----------------------------
 && echo "Handle tensorflow installation 1.x/2.x, cpu/gpu: https://www.tensorflow.org/install/source#gpu" \
 && ( $(grep -q "tf" <<< "${ARG_PROFILE_PYTHON}") && ( \
         V=$($(grep -q "tf1" <<< "${ARG_PROFILE_PYTHON}") && echo "1" || echo "2" ) \
         TF=$( [ "$V" == "1" ] && echo "tensorflow-gpu" || echo "tensorflow") \
      && echo "${TF}==${V}.*" > "/opt/utils/install_list_PY_tf${V}.pip" \
    ) || echo "Skipping tf install" ) \
 # -----------------------------
 && echo "Handle pytorch installation 1.x only, cpu/gpu: https://pytorch.org/get-started/locally/" \
 && ( $(grep -q "torch" <<< "${ARG_PROFILE_PYTHON}") && ( \
         echo "If CUDA version < 11.7, install pytorch 1.x, else install pytorch 2.x; if cuda doesn't exist, install pytorch 2.x" \
      && export CUDA_VER_TORCH="117" && V=$([[ "${CUDA_VER:-999}" -lt "${CUDA_VER_TORCH}" ]] && echo "torch<2" || echo "torch") \
      && pip install --no-cache-dir --root-user-action=ignore -U --pre "${V}" torchvision torchaudio --index-url "https://download.pytorch.org/whl/${IDX}" \
    ) || echo "Skipping pytorch install" ) \
 # -----------------------------
 && echo "Handle paddle installation, cpu/gpu: https://www.paddlepaddle.org.cn/" \
 && ( $(grep -q "paddle" <<< "${ARG_PROFILE_PYTHON}") && ( \
         URL_PYPI_PADDLE="https://www.paddlepaddle.org.cn/packages/stable/${IDX}/" \
      && PADDLE=$( [ -x "$(command -v nvcc)" ] && echo "paddlepaddle-gpu" || echo "paddlepaddle") \
      && pip install --no-cache-dir --root-user-action=ignore -U --pre --index-url ${URL_PYPI_PADDLE} "${PADDLE}" \
    ) || echo "Skip paddle install" ) \
 # -----------------------------
 # && [ "${PIP_FIND_LINKS+set}" != "set" ] && echo "PIP_FIND_LINKS is not set!" || echo "PIP_FIND_LINKS is set to: ${PIP_FIND_LINKS}" \
 && for profile in $(echo $ARG_PROFILE_PYTHON | tr "," "\n") ; do ( \
      [ -f "/opt/utils/install_list_PY_${profile}.apt" ] && install_apt "/opt/utils/install_list_PY_${profile}.apt" || echo "apt install skipped for ${profile}" ; \
      [ -f "/opt/utils/install_list_PY_${profile}.pip" ] && install_pip "/opt/utils/install_list_PY_${profile}.pip" || echo "pip install skipped for ${profile}" ; \
    ) ; done \
 && if [ "$(echo "${IDX}" | cut -c1-2)" = "cu" ] && echo "${ARG_PROFILE_PYTHON}" | grep -qE "torch|paddle" ; then \
          echo "Try to uninstall nvidia python packages to reduce storage size..." \
       && pip freeze | grep -i '^nvidia-' | cut -d'=' -f1 | xargs -r pip uninstall -y \
       && apt-get -qq update --fix-missing && apt-get -qq install -y --no-install-recommends --allow-change-held-packages libcusparselt0 libnccl2 libnccl-dev ; \
    fi \
 # -----------------------------
 && if echo "${ARG_PROFILE_GO}" | grep -q "base" ; then \
       echo "Installing GO: ${ARG_PROFILE_GO}" && setup_GO ; \
    else \
       echo "Skip installing GO" ; \
    fi \
 # -----------------------------
 && if echo "${ARG_PROFILE_RUST}" | grep -q "base" ; then \
       echo "Installing rust: ${ARG_PROFILE_RUST}" && setup_rust ; \
    else \
       echo "Skip installing rust" ; \
    fi \
 # -----------------------------
 && if echo "${ARG_PROFILE_JULIA}" | grep -q "base" ; then \
       echo "Installing julia: ${ARG_PROFILE_JULIA}" && setup_julia ; \
    else \
       echo "Skip installing julia" ; \
    fi \
 # -----------------------------
 && if echo "${ARG_PROFILE_OCTAVE}" | grep -q "base" ; then \
       echo "Installing Octave: ${ARG_PROFILE_OCTAVE}" && setup_octave ; \
    else \
       echo "Skip installing octave" ; \
    fi \
 # -----------------------------
 && echo "Clean up and display components version information..." \
 && list_installed_packages && install__clean
