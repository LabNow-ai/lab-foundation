#!/bin/sh

usage() {
  cat <<'EOF'
Usage: script-sync-image.sh [IMAGE] [options]
  --file-auth FILE            image-syncer auth file
  --file-workflow FILE        GitHub Actions workflow YAML
  --image-namespace-src NAME  Source image namespace (default: IMG_NAMESPACE_SRC or library)
  --image-namespace-dst NAME  Destination image namespace (default: source namespace)
  --source-registry NAME      Source registry (default: REGISTRY_URL or docker.io)
  --target-registry NAME      Target registry; repeat or use comma-separated values
  --image IMAGE               Sync one fully-qualified image path instead of workflow jobs
  --help                      Show this help
EOF
}

file_workflow=.github/workflows/build-docker.yml
file_auth=${FILE_AUTH:-}
namespace_img_src=${IMG_NAMESPACE_SRC:-library}
namespace_img_dst=${IMG_NAMESPACE_DST:-}
registry_source=${REGISTRY_URL:-docker.io}
registries_target=${DOCKER_MIRROR_REGISTRY:-}
image_single=

append_target_registries() {
  if [ -n "$registries_target" ]; then
    registries_target="${registries_target},$1"
  else
    registries_target=$1
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --file-workflow|--workflow-file)
      [ "$#" -ge 2 ] || { echo "Missing value for $1" >&2; exit 2; }
      file_workflow=$2
      shift 2
      ;;
    --file-workflow=*|--workflow-file=*)
      file_workflow=${1#*=}
      shift
      ;;
    --image-namespace-src|--image-namespace)
      [ "$#" -ge 2 ] || { echo "Missing value for $1" >&2; exit 2; }
      namespace_img_src=$2
      shift 2
      ;;
    --image-namespace-src=*|--image-namespace=*)
      namespace_img_src=${1#*=}
      shift
      ;;
    --image-namespace-dst)
      [ "$#" -ge 2 ] || { echo "Missing value for --image-namespace-dst" >&2; exit 2; }
      namespace_img_dst=$2
      shift 2
      ;;
    --image-namespace-dst=*)
      namespace_img_dst=${1#*=}
      shift
      ;;
    --source-registry)
      [ "$#" -ge 2 ] || { echo "Missing value for $1" >&2; exit 2; }
      registry_source=$2
      shift 2
      ;;
    --source-registry=*)
      registry_source=${1#*=}
      shift
      ;;
    --target-registry)
      shift
      target_found=false
      while [ "$#" -gt 0 ] && [ "${1#--}" = "$1" ]; do
        append_target_registries "$1"
        target_found=true
        shift
      done
      [ "$target_found" = true ] || { echo "Missing value for --target-registry" >&2; exit 2; }
      ;;
    --target-registry=*)
      append_target_registries "${1#*=}"
      shift
      ;;
    --file-auth|--auth-file)
      [ "$#" -ge 2 ] || { echo "Missing value for $1" >&2; exit 2; }
      file_auth=$2
      shift 2
      ;;
    --file-auth=*|--auth-file=*)
      file_auth=${1#*=}
      shift
      ;;
    --image)
      [ "$#" -ge 2 ] || { echo "Missing value for $1" >&2; exit 2; }
      image_single=$2
      shift 2
      ;;
    --image=*)
      image_single=${1#*=}
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      if [ -z "$image_single" ] && [ "${1#-}" = "$1" ]; then
        image_single=$1
        shift
      else
        echo "Unknown argument: $1" >&2
        usage >&2
        exit 2
      fi
      ;;
  esac
done

if [ -z "$namespace_img_dst" ]; then
  namespace_img_dst=$namespace_img_src
fi

export SOURCE_REGISTRY=$registry_source

command -v yq >/dev/null 2>&1 || { echo "Required command not found: yq" >&2; exit 1; }
command -v image-syncer >/dev/null 2>&1 || { echo "Required command not found: image-syncer" >&2; exit 1; }

tmp_dir=$(mktemp -d) || { echo "Unable to create temporary directory" >&2; exit 1; }
trap 'rm -rf "$tmp_dir"' 0
trap 'exit 1' HUP INT TERM
file_names=$tmp_dir/names
file_names_raw=$tmp_dir/raw-names
file_targets=$tmp_dir/targets
file_config=$tmp_dir/config.json

if [ -n "$image_single" ]; then
  printf '%s\n' "$image_single" > "$file_names"
else
  if [ ! -r "$file_workflow" ]; then
    echo "Workflow file is not readable: $file_workflow" >&2
    exit 1
  fi
  if ! yq -r '.jobs[]? | select(.name != null) | .name' "$file_workflow" > "$file_names_raw"; then
    echo "Failed to parse workflow file: $file_workflow" >&2
    exit 1
  fi
  while IFS= read -r name_job || [ -n "$name_job" ]; do
    printf '%s\n' "$name_job" | tr ',' '\n' >> "$file_names"
  done < "$file_names_raw"
fi

printf '%s\n' "$registries_target" | tr ',' '\n' |
  sed 's/^[[:space:]]*//; s/[[:space:]]*$//; /^$/d' > "$file_targets"
if [ ! -s "$file_targets" ]; then
  printf '%s\n' registry.cn-beijing.aliyuncs.com registry.cn-hangzhou.aliyuncs.com > "$file_targets"
fi

status_total=0
while IFS= read -r image_name || [ -n "$image_name" ]; do
  if [ -z "$image_single" ]; then
    path_image_src=$namespace_img_src/$image_name
    path_image_dst=$namespace_img_dst/$image_name
  else
    path_image_src=$image_name
    path_image_dst=$image_name
  fi
  image_source=$registry_source/$path_image_src
  echo "Docker image sync job name found: $path_image_src"

  if [ -n "$file_auth" ]; then
    export SOURCE_IMAGE=$image_source TARGET_REGISTRIES=
    while IFS= read -r registry_target || [ -n "$registry_target" ]; do
      image_destination=$registry_target/$path_image_dst
      if [ -n "$TARGET_REGISTRIES" ]; then
        TARGET_REGISTRIES=$TARGET_REGISTRIES,$image_destination
      else
        TARGET_REGISTRIES=$image_destination
      fi
    done < "$file_targets"
    export TARGET_REGISTRIES
    if ! yq -n -o=json '{"images": {(strenv(SOURCE_IMAGE)): (strenv(TARGET_REGISTRIES) | split(","))}}' > "$file_config"; then
      echo "Failed to generate image config for $path_image_src" >&2
      status_total=$((status_total + 1))
      continue
    fi
    image-syncer --proc=16 --retries=2 "--auth=$file_auth" "--images=$file_config"
    status_sync=$?
    status_total=$((status_total + status_sync))
  else
    if [ -z "${DOCKER_MIRROR_REGISTRY_USERNAME:-}" ] || [ -z "${DOCKER_MIRROR_REGISTRY_PASSWORD:-}" ]; then
      echo "DOCKER_MIRROR_REGISTRY_USERNAME and DOCKER_MIRROR_REGISTRY_PASSWORD are required without --file-auth" >&2
      exit 1
    fi
    if [ -z "${DOCKER_REGISTRY_USERNAME:-}" ] || [ -z "${DOCKER_REGISTRY_PASSWORD:-}" ]; then
      echo "DOCKER_REGISTRY_USERNAME and DOCKER_REGISTRY_PASSWORD are required without --file-auth" >&2
      exit 254
    fi
    while IFS= read -r registry_target || [ -n "$registry_target" ]; do
      image_destination=$registry_target/$path_image_dst
      export SOURCE_IMAGE=$image_source TARGET_REGISTRY=$registry_target DESTINATION=$image_destination
      if ! yq -n -o=json \
        '{"images": {(strenv(SOURCE_IMAGE)): [strenv(DESTINATION)]}, "auth": {(strenv(TARGET_REGISTRY)): {"username": strenv(DOCKER_MIRROR_REGISTRY_USERNAME), "password": strenv(DOCKER_MIRROR_REGISTRY_PASSWORD)}}} * {"auth": {(strenv(SOURCE_REGISTRY)): {"username": strenv(DOCKER_REGISTRY_USERNAME), "password": strenv(DOCKER_REGISTRY_PASSWORD)}}}' \
        > "$file_config"; then
        echo "Failed to generate image config for $path_image_src" >&2
        status_total=$((status_total + 1))
        continue
      fi
      image-syncer --proc=16 --retries=2 "--config=$file_config"
      status_sync=$?
      status_total=$((status_total + status_sync))
    done < "$file_targets"
  fi
done < "$file_names"

exit "$status_total"
