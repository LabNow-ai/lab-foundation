# Distributed under the terms of the Modified BSD License.

# latest # default value: Latest LTS version of Ubuntu (https://hub.docker.com/_/ubuntu)
ARG BASE_IMG="ubuntu:noble"
FROM ${BASE_IMG}

LABEL maintainer="postmaster@labnow.ai"

USER root

COPY work /opt/utils/

ENV SHELL=/bin/bash \
    DEBIAN_FRONTEND=noninteractive \
    LC_ALL="" \
    LC_CTYPE="C.UTF-8" \
    LC_TYPE="en_US.UTF-8" \
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US.UTF-8" \
    HOME_DIR=/root

# '-c' option make bash commands are read from string.
#   If there are arguments after the string, they are assigned to the positional parameters, starting with $0.
# '--login': make bash first reads and executes commands from  the file /etc/profile, if that file exists.
#   After that, it looks for ~/.bash_profile, ~/.bash_login, and ~/.profile, in that order, and reads and executes commands from the first one that exists and is readable.
SHELL ["/bin/bash", "--login", "-c"]

# --> Install OS libraries and setup some configurations
RUN set -eux && cd /tmp \
 && apt-get -qq update --fix-missing && apt-get -y -qq upgrade \
 && apt-get -qq install -y --no-install-recommends \
     apt-utils apt-transport-https ca-certificates gnupg2 dirmngr locales sudo lsb-release curl \
 && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \
 && echo "en_US.UTF-8 UTF-8"             >  /etc/locale.gen && locale-gen \
 && echo "ALL ALL=(ALL) NOPASSWD:ALL"    >> /etc/sudoers \
 && mv /root/.bashrc /etc/profile.d/bash.bashrc.sh \
 && LINE_SET_FLAG='export ENTER_PROFILE=$(date +%Y.%m%d.%H%M)' \
 && LINE_CHK_FLAG='[ $BASH ] && [ -f /etc/profile  ] && [ -z $ENTER_PROFILE ] && . /etc/profile' \
 # Add a check variable `ENTER_PROFILE` to see if /etc/profile is executed or not
 && echo -e "${LINE_SET_FLAG} \n$(cat /etc/profile)"                > /etc/profile \
 # if /etc/profile haven't been executed, execute it.
 && echo -e "${LINE_CHK_FLAG} \n$(cat /etc/bash.bashrc)"            > /etc/bash.bashrc \
 && echo '[ $BASH ] && [ -f /root/.bashrc ] && . /root/.bashrc'     >> /etc/bash.bashrc \
 && chmod +x /opt/utils/*.sh /opt/utils/localize/*.sh \
 # Clean up and display components version information...
 && source /opt/utils/script-utils.sh && install__clean

WORKDIR $HOME_DIR
