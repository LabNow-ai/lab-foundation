ARG BASE_NAMESPACE
ARG BASE_IMG="busybox"
FROM ${BASE_NAMESPACE:+$BASE_NAMESPACE/}${BASE_IMG}

LABEL maintainer="postmaster@labnow.ai"
LABEL usage="docker run --rm -it -v $(pwd):/tmp `docker-image-name`"
ENV DIR_DATA="/home/"
WORKDIR ${DIR_DATA}
CMD ["sh", "-c", "ls -alh /home && cp -r /home/* /tmp/"]

RUN set -eux \
 && mkdir -pv libnvidia-container \
 && wget https://api.github.com/repos/nvidia/libnvidia-container/tarball/gh-pages -O - | tar -zx --strip-components=1 -C ./libnvidia-container \
 && pwd && ls -alh && du -h -d1
