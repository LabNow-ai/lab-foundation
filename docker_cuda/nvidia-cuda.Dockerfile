# Distributed under the terms of the Modified BSD License.

ARG BASE_NAMESPACE
ARG BASE_IMG="cuda:latest"
FROM ${BASE_NAMESPACE:+$BASE_NAMESPACE/}${BASE_IMG}

LABEL maintainer="postmaster@labnow.ai"

# Let NVIDIA docker ignore cuda requirement check
ENV NVIDIA_DISABLE_REQUIRE=1

# For cuda version 10.0, the image is solely serverd for legacy tensorflow 1.15, which requires python 3.7
# For tensorflow 2.x or torch, python>=3.9 is supported.
RUN set -eux && echo ${CUDA_VERSION} && nvcc --version \
 # HACK & FIX: for some old version of NVIDIA docker images, sys python version is too old, update debpython
 && URL_PY3_DEP="https://salsa.debian.org/cpython-team/python3-defaults/-/archive/master/python3-defaults-master.zip?path=debpython" \
 && curl -o /tmp/TMP.zip -sL "${URL_PY3_DEP}" && unzip -q -d /tmp/ /tmp/TMP.zip && rm /tmp/TMP.zip \
 && mkdir -pv /usr/share/python3/debpython/ \
 && cp -rf /tmp/python3-defaults-master-debpython/debpython/* /usr/share/python3/debpython/ \
 && rm -rf /tmp/python3-defaults-master-debpython \
 # Setup nvtop
 && source /opt/utils/script-setup.sh \
 && setup_nvtop \
 && install__clean
