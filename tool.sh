#!/bin/bash
if [ "${GITHUB_ACTIONS:-"false"}" != "true" ]; then
  export CI_PROJECT_BRANCH=$(git branch --show-current)         CI_PROJECT_NAME=LabNow/lab-foundation
  export REGISTRY_SRC=quay.io REGISTRY_DST=quay.io
  echo "Not running in GitHub Action."
else
  set -exu
  export CI_PROJECT_BRANCH=${GITHUB_HEAD_REF:-$GITHUB_REF_NAME} CI_PROJECT_NAME=${CI_PROJECT_NAME:-$GITHUB_REPOSITORY}
  echo "Running in GitHub Actions and Setup Env:"
  [ ! -f /etc/docker/daemon.json ] && sudo tee /etc/docker/daemon.json > /dev/null <<< '{}' ;
  jq '.experimental=true | ."data-root"="/mnt/docker"' /etc/docker/daemon.json > /tmp/daemon.json && sudo mv /tmp/daemon.json /etc/docker/ ;
  ( sudo service docker restart || true ) && cat /etc/docker/daemon.json && docker info ;
fi


CI_PROJECT_SPACE=${CI_PROJECT_BRANCH%%/*}

# If on the main branch, image namespace will be same as CI_PROJECT_NAME's name space;
# else (not main branch), image namespace = {CI_PROJECT_NAME's name space} + "0" + {1st substr before / in CI_PROJECT_SPACE}.
[ "${CI_PROJECT_BRANCH}" = "main" ] && NAMESPACE_SUFFIX="" || NAMESPACE_SUFFIX="0${CI_PROJECT_SPACE}" ;
export CI_PROJECT_NAMESPACE="$(dirname "${CI_PROJECT_NAME}")${NAMESPACE_SUFFIX}" ;

export IMG_NAMESPACE=$(echo "${CI_PROJECT_NAMESPACE}" | awk '{print tolower($0)}')
export IMG_NAMESPACE_SRC=$(echo "${IMG_NAMESPACE_SRC:-$IMG_NAMESPACE}" | awk '{print tolower($0)}')
export IMG_NAMESPACE_DST=$(echo "${IMG_NAMESPACE_DST:-$IMG_NAMESPACE}" | awk '{print tolower($0)}')
export IMG_PREFIX_SRC=$(echo "${REGISTRY_SRC:-"quay.io"}/${IMG_NAMESPACE_SRC}" | awk '{print tolower($0)}')
export IMG_PREFIX_DST=$(echo "${REGISTRY_DST:-"docker.io"}/${IMG_NAMESPACE_SRC}" | awk '{print tolower($0)}')
export TAG_SUFFIX="-$(git rev-parse --short HEAD)"

echo "--------> CI_PROJECT_NAMESPACE=${CI_PROJECT_NAMESPACE}"
echo "--------> DOCKER_IMG_NAMESPACE_SRC=${IMG_NAMESPACE_SRC}"
echo "--------> DOCKER_IMG_NAMESPACE_DST=${IMG_NAMESPACE_DST}"
echo "--------> DOCKER_IMG_PREFIX_SRC=${IMG_PREFIX_SRC}"
echo "--------> DOCKER_IMG_PREFIX_DST=${IMG_PREFIX_DST}"
echo "--------> DOCKER_TAG_SUFFIX=${TAG_SUFFIX}"


build_image() {
    echo "$@" ;
    local IMG=$1 TAG=$2 FILE=$3; shift 3; local VER=$(date +%Y.%m%d.%H%M)${TAG_SUFFIX} WORKDIR="$(dirname "$FILE")";
    BUILDKIT_PROGRESS=plain DOCKER_BUILDKIT=1 \
      docker build --compress --force-rm=true -t "${IMG_PREFIX_DST}/${IMG}:${TAG}" -f "$FILE" \
      --build-arg "BASE_NAMESPACE=${IMG_PREFIX_SRC}" "$@" "${WORKDIR}"
    docker tag "${IMG_PREFIX_DST}/${IMG}:${TAG}" "${IMG_PREFIX_DST}/${IMG}:${VER}"
    echo "${IMG_PREFIX_DST}/${IMG}:${TAG}"
}

build_image_no_tag() {
    echo "$@" ;
    local IMG=$1 TAG=$2 FILE=$3; shift 3; local WORKDIR="$(dirname "$FILE")";
    BUILDKIT_PROGRESS=plain DOCKER_BUILDKIT=1 \
      docker build --compress --force-rm=true -t "${IMG_PREFIX_DST}/${IMG}:${TAG}" -f "$FILE" \
      --build-arg "BASE_NAMESPACE=${IMG_PREFIX_SRC}" "$@" "${WORKDIR}"
    echo "${IMG_PREFIX_DST}/${IMG}:${TAG}"
}

alias_image() {
    local IMG_1=$1 TAG_1=$2 IMG_2=$3 TAG_2=$4; shift 4; local VER=$(date +%Y.%m%d.%H%M)${TAG_SUFFIX};
    docker tag "${IMG_PREFIX_DST}/${IMG_1}:${TAG_1}" "${IMG_PREFIX_DST}/${IMG_2}:${TAG_2}"
    docker tag "${IMG_PREFIX_DST}/${IMG_2}:${TAG_2}" "${IMG_PREFIX_DST}/${IMG_2}:${VER}"
}

push_image() {
    local KEYWORD="${1:-second}" IMAGES IMG status;
    docker image prune --force && docker images;
    IMAGES=$(docker images --format "{{.Repository}}\t{{.Tag}}\t{{.CreatedSince}}" | grep "${IMG_PREFIX_DST}" | grep "${KEYWORD}" | awk '{print $1 ":" $2}') ;
    [ -n "${IMAGES}" ] || { echo "!! No images matched keyword: ${KEYWORD}"; return 1; }
    echo "$DOCKER_REGISTRY_PASSWORD" | docker login "${REGISTRY_DST}" -u "$DOCKER_REGISTRY_USERNAME" --password-stdin ;
    for IMG in $(echo "${IMAGES}" | tr " " "\n") ;
    do
      docker push "${IMG}";
      status=$?;
      echo "[${status}] Image pushed > ${IMG}";
    done
}

clear_images() {
    local KEYWORD=${1:-'days ago\|weeks ago\|months ago\|years ago'}; # if no keyword is provided, clear all images built days ago
    local IMGS_1=$(docker images | grep "${KEYWORD}" | awk '{print $1 ":" $2}') ;
    local IMGS_2=$(docker images | grep "${KEYWORD}" | awk '{print $3}') ;
    local IMG status

    for IMG in $(echo "$IMGS_1 $IMGS_2" | tr " " "\n") ; do
      docker rmi "${IMG}" ; status=$?; echo "[${status}] image removed > ${IMG}";
    done
    docker image prune --force && docker images ;
}


remove_folder() {
    local dir
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
    df -h ;
}
