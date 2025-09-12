# Distributed under the terms of the Modified BSD License.

ARG BASE_NAMESPACE
ARG BASE_IMG="atom"
FROM ${BASE_NAMESPACE:+$BASE_NAMESPACE/}${BASE_IMG}

LABEL maintainer="postmaster@labnow.ai"

ARG SYS_PY_REPLACE="true"
ARG PYTHON_VERSION="3.12"

ENV CONDA_PREFIX=/opt/conda

RUN set -eux && source /opt/utils/script-setup.sh && source /opt/utils/script-setup-sys.sh \
 && export PATH=${CONDA_PREFIX}/bin:$PATH \
 && install_apt /opt/utils/install_list_base.apt \
 && echo "Install tini:" && setup_tini \
 && export SYS_PY_REPLACE=${SYS_PY_REPLACE} \
 && export SYS_PY_EXISTS=$( [ -x "$(command -v python3)" ] && echo 'true' || echo 'false' ) && echo "@ Detect OS Py3 installed: ${SYS_PY_EXISTS:-error}" \
 && echo "Install Mamba:" && setup_mamba \
 && echo "Install Python ${PYTHON_VERSION} and conda:" && setup_conda_with_mamba ${PYTHON_VERSION} \
 && PY_VER=$(/opt/conda/bin/python -c 'import sys; print(f"{sys.version_info.major}{sys.version_info.minor:02d}")' 2>/dev/null) \
 && ( (( $PY_VER >= 308 )) && pip install -U uv || echo "Skip uv install" ) \
 && echo "Backup the conda version of platform.py as it's different from the system version." \
 && cp "${CONDA_PREFIX}/lib/python${PYTHON_VERSION}"/platform.py "${CONDA_PREFIX}/lib/python${PYTHON_VERSION}"/platform.py.bak \
 && if $( ${SYS_PY_EXISTS:-false} && ${SYS_PY_REPLACE:-false} ) ; then \
       py3versions -d \
    && PYTHON_VERSION_DEFAULT=$(py3versions -v -i) \
    && PYTHON_PTH_FILE=$("${CONDA_PREFIX}"/bin/python3 -c 'import sys;print(sys.path[-1]+"/usr_share.pth")') \
    && echo "Found default system python3 version: ${PYTHON_VERSION_DEFAULT}" \
    && echo "Replace system Python3 with conda Python - note that /bin and /sbin are symlinks of /usr/bin in docker image ubuntu" \
    && sed -i "s/${PYTHON_VERSION_DEFAULT}/${PYTHON_VERSION}/g" /usr/share/python3/debian_defaults \
    && echo "/usr/share/pyshared/" >>  "${PYTHON_PTH_FILE}" \
    && echo "/usr/share/python3/"  >>  "${PYTHON_PTH_FILE}" \
    && cp -rf  /usr/lib/python3/dist-packages/* ./ \
    && rm -rf $(/usr/bin/python3 -c 'import sys; print(" ".join(i for i in sys.path if "python" in i))') /usr/bin/python3* /usr/lib/python${PYTHON_VERSION} \
    && rm -rf /usr/lib/python${PYTHON_VERSION} && ln -sf "${CONDA_PREFIX}"/lib/python${PYTHON_VERSION} /usr/lib/ ; \
 else \
     echo "Not replacing OS default python." ; \
 fi \
 && ln -sf "${CONDA_PREFIX}"/bin/python3.* /usr/bin/ \
 && ln -sf "${CONDA_PREFIX}"/bin/pip       /usr/bin/ \
 && ln -sf "/usr/bin/python${PYTHON_VERSION}" /usr/bin/python  \
 && ln -sf "/usr/bin/python${PYTHON_VERSION}" /usr/bin/python3 \
 && lsb_release -a \
 && which python && python --version && ls -alh /usr/bin/python* \
 && install__clean && fix_permission 0 /opt
