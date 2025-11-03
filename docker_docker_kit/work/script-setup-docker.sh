source /opt/utils/script-utils.sh


setup_docker_compose() {
     ARCH=$(uname -m) \
  && VER_COMPOSE=$(curl -sL https://github.com/docker/compose/releases.atom | grep 'releases/tag' | head -1 | grep -Po '\d[.\d]+') \
  && URL_COMPOSE="https://github.com/docker/compose/releases/download/v${VER_COMPOSE}/docker-compose-linux-${ARCH}" \
  && echo "Downloading Compose from: ${URL_COMPOSE}" \
  && sudo curl -o /usr/bin/docker-compose -sL ${URL_COMPOSE} \
  && sudo chmod +x /usr/bin/docker-compose ;
  
  type docker-compose && echo "@ Version of docker-compose: $(docker-compose --version)" || return -1 ;
}

setup_docker_syncer() {
     ARCH=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/') \
  && VER_SYNCER="$(curl -sL https://github.com/AliyunContainerService/image-syncer/releases.atom | grep 'releases/tag' | head -1 | grep -Po '\d[.\d]+')" \
  && URL_SYNCER="https://github.com/AliyunContainerService/image-syncer/releases/download/v${VER_SYNCER}/image-syncer-v${VER_SYNCER}-linux-${ARCH}.tar.gz" \
  && echo "Downloading image-syncer from: ${URL_SYNCER}" \
  && curl -o /tmp/image_syncer.tgz -sL ${URL_SYNCER} \
  && mkdir -pv /tmp/image_syncer && tar -zxvf /tmp/image_syncer.tgz -C /tmp/image_syncer \
  && sudo chmod +x /tmp/image_syncer/image-syncer \
  && sudo mv /tmp/image_syncer/image-syncer /usr/bin/ \
  && rm -rf /tmp/image_syncer* ;
  
  type image-syncer && echo "@ image-syncer installed to: $(which image-syncer)" || return -1 ;
}
