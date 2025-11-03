#!/bin/bash
set -xu

CI_PROJECT_NAME=${CI_PROJECT_NAME:-$GITHUB_REPOSITORY}
CI_PROJECT_BRANCH=${GITHUB_HEAD_REF:-"main"}
CI_PROJECT_SPACE=$(echo "${CI_PROJECT_BRANCH}" | cut -f1 -d'/')

# If on the main branch, image namespace will be same as CI_PROJECT_NAME's name space;
# else (not main branch), image namespace = {CI_PROJECT_NAME's name space} + "0" + {1st substr before / in CI_PROJECT_SPACE}.
[ "${CI_PROJECT_BRANCH}" = "main" ] && NAMESPACE_SUFFIX="" || NAMESPACE_SUFFIX="0${CI_PROJECT_SPACE}" ;
export CI_PROJECT_NAMESPACE="$(dirname ${CI_PROJECT_NAME})${NAMESPACE_SUFFIX}" ;

export IMG_NAMESPACE=$(echo "${CI_PROJECT_NAMESPACE}" | awk '{print tolower($0)}')
export IMG_PREFIX_SRC=$(echo "${REGISTRY_SRC:-"docker.io"}/${IMG_NAMESPACE}" | awk '{print tolower($0)}')
export IMG_PREFIX_DST=$(echo "${REGISTRY_DST:-"docker.io"}/${IMG_NAMESPACE}" | awk '{print tolower($0)}')
export TAG_SUFFIX="-$(git rev-parse --short HEAD)"

echo "--------> CI_PROJECT_NAMESPACE=${CI_PROJECT_NAMESPACE}"
echo "--------> DOCKER_IMG_NAMESPACE=${IMG_NAMESPACE}"
echo "--------> DOCKER_IMG_PREFIX_SRC=${IMG_PREFIX_SRC}"
echo "--------> DOCKER_IMG_PREFIX_DST=${IMG_PREFIX_DST}"
echo "--------> DOCKER_TAG_SUFFIX=${TAG_SUFFIX}"

build_image_dry_run() {
    IMG=$1; TAG=$2; FILE=$3; shift 3; WORKDIR="$(dirname $FILE)";
    PLATFORM=${DOCKER_PLATFORM:-$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/')} ;
    echo "[DRY RUN] docker buildx build --compress --force-rm=true --platform ${PLATFORM} -t ${IMG_PREFIX_DST}/${IMG}:${TAG} -f ${FILE} --build-arg BASE_NAMESPACE=${IMG_PREFIX_SRC} $@ ${WORKDIR}" ;
}

build_image() {
    IMG=$1; TAG=$2; FILE=$3; shift 3; WORKDIR="$(dirname $FILE)"; VER=$(date +%Y.%m%d.%H%M)${TAG_SUFFIX};
    PLATFORM=${DOCKER_PLATFORM:-$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/')} ;

    PUSH=${PUSH:-true} ; TAG_VER=${TAG_VER:-true} ; TAGS_EXTRA=${TAGS_EXTRA:-} ;
    TAG_ARGS=("-t" "${IMG_PREFIX_DST:+$IMG_PREFIX_DST/}${IMG}:${TAG}"); [ "$TAG_VER" = "true" ] && TAG_ARGS+=("-t" "${IMG_PREFIX_DST}/${IMG}:${VER}"); for t in ${TAGS_EXTRA}; do TAG_ARGS+=("-t" "${IMG_PREFIX_DST}/${IMG}:${t}"); done ;
    OPT_OUTPUT=$([ "$PUSH" = "true" ] && echo "--push" || echo "--load") ;

    docker buildx use multiarch || docker buildx create --name multiarch --driver docker-container --use ;
    docker buildx inspect ;
    registry_login ;
    docker buildx build --compress --force-rm=true --platform "${PLATFORM}" ${OPT_OUTPUT} "${TAG_ARGS[@]}" -f "$FILE" --build-arg "BASE_NAMESPACE=${IMG_PREFIX_SRC}" "$@" "${WORKDIR}" ;
}

registry_login() {
    echo "$DOCKER_REGISTRY_PASSWORD" | docker login "${REGISTRY_DST}" -u "$DOCKER_REGISTRY_USERNAME" --password-stdin ;
}

push_image() {
    KEYWORD="${1:-second}";
    docker image prune --force && docker images | sort;
    IMAGES=$(docker images | grep "${KEYWORD}" | awk '{print $1 ":" $2}') ;
    registry_login ;
    for IMG in $(echo "${IMAGES}" | tr " " "\n") ;
    do
      docker push "${IMG}";
      status=$?;
      echo "[${status}] Image pushed > ${IMG}";
    done
}

clear_images() {
    KEYWORD=${1:-'days ago\|weeks ago\|months ago\|years ago'}; # if no keyword is provided, clear all images build days ago
    IMGS_1=$(docker images | grep "${KEYWORD}" | awk '{print $1 ":" $2}') ;
    IMGS_2=$(docker images | grep "${KEYWORD}" | awk '{print $3}') ;

    for IMG in $(echo "$IMGS_1 $IMGS_2" | tr " " "\n") ; do
      docker rmi "${IMG}" || true; status=$?; echo "[${status}] image removed > ${IMG}";
    done
    docker image prune --force && docker images ;
}

remove_folder() {
    for dir in "$@"; do
        if [ -d "$dir" ]; then
            echo "Removing folder: $dir" ;
            sudo du -h -d1 "$dir" || true ;
            sudo rm -rf "$dir" || true ;
        else
            echo "Warn: directory not found: $dir" ;
        fi
    done
}

free_diskspace() {
    remove_folder /usr/share/dotnet ; # /usr/local/lib/android /var/lib/docker
    df -h
}

setup_github_actions() {
    [ ! -f /etc/docker/daemon.json ] && sudo tee /etc/docker/daemon.json > /dev/null <<< '{}' ;
    jq '.experimental=true | ."data-root"="/mnt/docker"' /etc/docker/daemon.json > /tmp/daemon.json && sudo mv /tmp/daemon.json /etc/docker/ ;
    ( sudo service docker restart || true ) && cat /etc/docker/daemon.json && docker info ;
}
[ "$GITHUB_ACTIONS" = "true" ] && echo "Running in GitHub Actions and Setup Env: $(setup_github_actions)"
