#!/bin/sh

usage() {
  cat <<'EOF'
Usage: script-sync-image.sh [IMAGE] [options]
  --file-auth FILE         image-syncer auth file
  --file-workflow FILE     GitHub Actions workflow YAML
  --image-namespace NAME   Image namespace (default: IMG_NAMESPACE or library)
  --source-registry NAME   Source registry (default: REGISTRY_URL or docker.io)
  --target-registry NAME   Target registry; repeat or use comma-separated values
  --image IMAGE            Sync one fully-qualified image path instead of workflow jobs
  --help                   Show this help
EOF
}

file_workflow=.github/workflows/build-docker.yml
file_auth=${FILE_AUTH:-}
image_namespace=${IMG_NAMESPACE:-library}
source_registry=${REGISTRY_URL:-docker.io}
target_registries=${DOCKER_MIRROR_REGISTRY:-}
single_image=

append_targets() {
  if [ -n "$target_registries" ]; then
    target_registries="${target_registries},$1"
  else
    target_registries=$1
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --file-workflow)
      [ "$#" -ge 2 ] || { echo "Missing value for --file-workflow" >&2; exit 2; }
      file_workflow=$2
      shift 2
      ;;
    --file-workflow=*)
      file_workflow=${1#*=}
      shift
      ;;
    --image-namespace)
      [ "$#" -ge 2 ] || { echo "Missing value for --image-namespace" >&2; exit 2; }
      image_namespace=$2
      shift 2
      ;;
    --image-namespace=*)
      image_namespace=${1#*=}
      shift
      ;;
    --source-registry)
      [ "$#" -ge 2 ] || { echo "Missing value for --source-registry" >&2; exit 2; }
      source_registry=$2
      shift 2
      ;;
    --source-registry=*)
      source_registry=${1#*=}
      shift
      ;;
    --target-registry)
      shift
      found_target=false
      while [ "$#" -gt 0 ] && [ "${1#--}" = "$1" ]; do
        append_targets "$1"
        found_target=true
        shift
      done
      [ "$found_target" = true ] || { echo "Missing value for --target-registry" >&2; exit 2; }
      ;;
    --target-registry=*)
      append_targets "${1#*=}"
      shift
      ;;
    --file-auth)
      [ "$#" -ge 2 ] || { echo "Missing value for --file-auth" >&2; exit 2; }
      file_auth=$2
      shift 2
      ;;
    --file-auth=*)
      file_auth=${1#*=}
      shift
      ;;
    --image)
      [ "$#" -ge 2 ] || { echo "Missing value for --image" >&2; exit 2; }
      single_image=$2
      shift 2
      ;;
    --image=*)
      single_image=${1#*=}
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      if [ -z "$single_image" ] && [ "${1#-}" = "$1" ]; then
        single_image=$1
        shift
      else
        echo "Unknown argument: $1" >&2
        usage >&2
        exit 2
      fi
      ;;
  esac
done

export SOURCE_REGISTRY=$source_registry

command -v yq >/dev/null 2>&1 || { echo "Required command not found: yq" >&2; exit 1; }
command -v image-syncer >/dev/null 2>&1 || { echo "Required command not found: image-syncer" >&2; exit 1; }

tmp_dir=$(mktemp -d) || { echo "Unable to create temporary directory" >&2; exit 1; }
trap 'rm -rf "$tmp_dir"' 0
trap 'exit 1' HUP INT TERM
names_file=$tmp_dir/names
raw_names_file=$tmp_dir/raw-names
targets_file=$tmp_dir/targets
config_file=$tmp_dir/config.json

if [ -n "$single_image" ]; then
  printf '%s\n' "$single_image" > "$names_file"
else
  if [ ! -r "$file_workflow" ]; then
    echo "Workflow file is not readable: $file_workflow" >&2
    exit 1
  fi
  if ! yq -r '.jobs[]? | select(.name != null) | .name' "$file_workflow" > "$raw_names_file"; then
    echo "Failed to parse workflow file: $file_workflow" >&2
    exit 1
  fi
  while IFS= read -r job_name || [ -n "$job_name" ]; do
    printf '%s\n' "$job_name" | tr ',' '\n' >> "$names_file"
  done < "$raw_names_file"
fi

printf '%s\n' "$target_registries" | tr ',' '\n' |
  sed 's/^[[:space:]]*//; s/[[:space:]]*$//; /^$/d' > "$targets_file"
if [ ! -s "$targets_file" ]; then
  printf '%s\n' registry.cn-beijing.aliyuncs.com registry.cn-hangzhou.aliyuncs.com > "$targets_file"
fi

ret=0
while IFS= read -r image || [ -n "$image" ]; do
  if [ -z "$single_image" ]; then
    image_path=$image_namespace/$image
  else
    image_path=$image
  fi
  source_image=$source_registry/$image_path
  echo "Docker image sync job name found: $image_path"

  if [ -n "$file_auth" ]; then
    export SOURCE_IMAGE=$source_image TARGET_REGISTRIES=
    while IFS= read -r target_registry || [ -n "$target_registry" ]; do
      destination=$target_registry/$image_path
      if [ -n "$TARGET_REGISTRIES" ]; then
        TARGET_REGISTRIES=$TARGET_REGISTRIES,$destination
      else
        TARGET_REGISTRIES=$destination
      fi
    done < "$targets_file"
    export TARGET_REGISTRIES
    if ! yq -n -o=json '{"images": {(strenv(SOURCE_IMAGE)): (strenv(TARGET_REGISTRIES) | split(","))}}' > "$config_file"; then
      echo "Failed to generate image config for $image_path" >&2
      ret=$((ret + 1))
      continue
    fi
    image-syncer --proc=16 --retries=2 "--auth=$file_auth" "--images=$config_file"
    status=$?
    ret=$((ret + status))
  else
    if [ -z "${DOCKER_MIRROR_REGISTRY_USERNAME:-}" ] || [ -z "${DOCKER_MIRROR_REGISTRY_PASSWORD:-}" ]; then
      echo "DOCKER_MIRROR_REGISTRY_USERNAME and DOCKER_MIRROR_REGISTRY_PASSWORD are required without --file-auth" >&2
      exit 1
    fi
    if [ -z "${DOCKER_REGISTRY_USERNAME:-}" ] || [ -z "${DOCKER_REGISTRY_PASSWORD:-}" ]; then
      echo "DOCKER_REGISTRY_USERNAME and DOCKER_REGISTRY_PASSWORD are required without --file-auth" >&2
      exit 254
    fi
    while IFS= read -r target_registry || [ -n "$target_registry" ]; do
      destination=$target_registry/$image_path
      export SOURCE_IMAGE=$source_image TARGET_REGISTRY=$target_registry DESTINATION=$destination
      if ! yq -n -o=json \
        '{"images": {(strenv(SOURCE_IMAGE)): [strenv(DESTINATION)]}, "auth": {(strenv(TARGET_REGISTRY)): {"username": strenv(DOCKER_MIRROR_REGISTRY_USERNAME), "password": strenv(DOCKER_MIRROR_REGISTRY_PASSWORD)}}} * {"auth": {(strenv(SOURCE_REGISTRY)): {"username": strenv(DOCKER_REGISTRY_USERNAME), "password": strenv(DOCKER_REGISTRY_PASSWORD)}}}' \
        > "$config_file"; then
        echo "Failed to generate image config for $image_path" >&2
        ret=$((ret + 1))
        continue
      fi
      image-syncer --proc=16 --retries=2 "--config=$config_file"
      status=$?
      ret=$((ret + status))
    done < "$targets_file"
  fi
done < "$names_file"

exit "$ret"
