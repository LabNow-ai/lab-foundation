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
  --image IMAGE               Sync one registry-relative source image path
  DOCKER_MIRROR_TARGETS       Comma-separated registry=namespace-template entries.
                              A single %s is replaced with IMG_NAMESPACE.
  --help                      Show this help
EOF
}

file_workflow=.github/workflows/build-docker.yml
file_auth=${FILE_AUTH:-}
namespace_img_src=${IMG_NAMESPACE_SRC:-library}
namespace_img_dst=${IMG_NAMESPACE_DST:-}
registry_source=${REGISTRY_URL:-docker.io}
registries_target=${DOCKER_MIRROR_REGISTRY:-}
mirror_targets=${DOCKER_MIRROR_TARGETS:-}
target_registry_cli=false
image_single=
option_value=
option_shift=

append_target_registries() {
  registries_target="${registries_target}${registries_target:+,}$1"
  target_registry_cli=true
}

read_option_value() {
  case "$2" in
    *=*) option_value=${2#*=}; option_shift=1 ;;
    *)
      [ "$#" -ge 3 ] || { echo "Missing value for $1" >&2; exit 2; }
      option_value=$3
      option_shift=2
      ;;
  esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --file-workflow|--workflow-file|--file-workflow=*|--workflow-file=*)
      read_option_value "$1" "$@"; file_workflow=$option_value; shift "$option_shift" ;;
    --image-namespace-src|--image-namespace|--image-namespace-src=*|--image-namespace=*)
      read_option_value "$1" "$@"; namespace_img_src=$option_value; shift "$option_shift" ;;
    --image-namespace-dst|--image-namespace-dst=*)
      read_option_value "$1" "$@"; namespace_img_dst=$option_value; shift "$option_shift" ;;
    --source-registry|--source-registry=*)
      read_option_value "$1" "$@"; registry_source=$option_value; shift "$option_shift" ;;
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
    --file-auth|--auth-file|--file-auth=*|--auth-file=*)
      read_option_value "$1" "$@"; file_auth=$option_value; shift "$option_shift" ;;
    --image|--image=*)
      read_option_value "$1" "$@"; image_single=$option_value; shift "$option_shift" ;;
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

if [ -n "$mirror_targets" ] && [ "$target_registry_cli" = true ]; then
  echo "Do not combine DOCKER_MIRROR_TARGETS with --target-registry" >&2
  exit 2
fi

if [ -z "$namespace_img_dst" ]; then
  namespace_img_dst=$namespace_img_src
fi
namespace_template_value=${IMG_NAMESPACE:-$namespace_img_dst}
use_target_map=false
[ -z "$mirror_targets" ] || use_target_map=true
if [ "$use_target_map" = true ] && [ -n "$registries_target" ]; then
  echo "DOCKER_MIRROR_TARGETS overrides DOCKER_MIRROR_REGISTRY" >&2
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
file_targets_raw=$tmp_dir/raw-targets
file_target_registries=$tmp_dir/target-registries
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
  tr ',' '\n' < "$file_names_raw" > "$file_names"
fi

if [ "$use_target_map" = true ]; then
  printf '%s\n' "$mirror_targets" | tr ',' '\n' |
    sed 's/^[[:space:]]*//; s/[[:space:]]*$//; /^$/d' > "$file_targets_raw"
  if [ ! -s "$file_targets_raw" ]; then
    echo "DOCKER_MIRROR_TARGETS contains no target mappings" >&2
    exit 2
  fi
  while IFS= read -r target_mapping || [ -n "$target_mapping" ]; do
    case "$target_mapping" in
      *=*) registry_target=${target_mapping%%=*}; namespace_template=${target_mapping#*=} ;;
      *) echo "Invalid target mapping (expected registry=namespace): $target_mapping" >&2; exit 2 ;;
    esac
    registry_target=$(printf '%s' "$registry_target" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    namespace_template=$(printf '%s' "$namespace_template" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    case "$registry_target" in
      ''|*/*|*://*|*[[:space:]]*) echo "Invalid target registry: $registry_target" >&2; exit 2 ;;
    esac
    [ -n "$namespace_template" ] || { echo "Target namespace is empty for $registry_target" >&2; exit 2; }

    case "$namespace_template" in
      *%s*)
        namespace_template_prefix=${namespace_template%%\%s*}
        namespace_template_suffix=${namespace_template#*%s}
        case "$namespace_template_prefix$namespace_template_suffix" in
          *%*|*[!a-zA-Z0-9._/-]*)
            echo "Invalid namespace template (use only one %s placeholder): $namespace_template" >&2
            exit 2
            ;;
        esac
        [ -n "$namespace_template_value" ] || {
          echo "IMG_NAMESPACE is empty; cannot expand target namespace: $namespace_template" >&2
          exit 2
        }
        target_namespace=$(printf "$namespace_template" "$namespace_template_value")
        ;;
      *%*) echo "Unsupported printf placeholder in: $namespace_template" >&2; exit 2 ;;
      *) target_namespace=$namespace_template ;;
    esac
    target_namespace=$(printf '%s' "$target_namespace" | tr '[:upper:]' '[:lower:]')
    case "$target_namespace" in
      ''|/*|*/|*//*|*[!a-z0-9._/-]*)
        echo "Invalid target namespace: $target_namespace" >&2
        exit 2
        ;;
    esac
    printf '%s\t%s\n' "$registry_target" "$target_namespace" >> "$file_targets"
  done < "$file_targets_raw"
else
  printf '%s\n' "$registries_target" | tr ',' '\n' |
    sed 's/^[[:space:]]*//; s/[[:space:]]*$//; /^$/d' > "$file_target_registries"
  if [ ! -s "$file_target_registries" ]; then
    printf '%s\n' registry.cn-beijing.aliyuncs.com registry.cn-hangzhou.aliyuncs.com > "$file_target_registries"
  fi
  while IFS= read -r registry_target || [ -n "$registry_target" ]; do
    printf '%s\t%s\n' "$registry_target" "$namespace_img_dst" >> "$file_targets"
  done < "$file_target_registries"
fi

status_total=0
run_image_sync() {
  image-syncer "$@"
  status_total=$((status_total + $?))
}

image_destination_for_target() {
  if [ "$use_target_map" = true ]; then
    printf '%s/%s/%s' "$1" "$2" "$image_path_suffix"
  else
    printf '%s/%s' "$1" "$path_image_dst"
  fi
}

while IFS= read -r image_name || [ -n "$image_name" ]; do
  path_image_src=$image_name
  path_image_dst=$image_name
  image_path_suffix=$image_name
  if [ -z "$image_single" ]; then
    path_image_src=$namespace_img_src/$image_name
    path_image_dst=$namespace_img_dst/$image_name
  elif [ "$use_target_map" = true ]; then
    case "$image_single" in
      "$namespace_img_src"/*) image_path_suffix=${image_single#"$namespace_img_src"/} ;;
      *)
        echo "With DOCKER_MIRROR_TARGETS, --image must start with source namespace '$namespace_img_src/'" >&2
        exit 2
        ;;
    esac
  fi
  image_source=$registry_source/$path_image_src
  echo "Docker image sync job name found: $path_image_src"

  if [ -n "$file_auth" ]; then
    export SOURCE_IMAGE=$image_source TARGET_REGISTRIES=
    while IFS="$(printf '\t')" read -r registry_target target_namespace || [ -n "$registry_target" ]; do
      image_destination=$(image_destination_for_target "$registry_target" "$target_namespace")
      if [ -n "$TARGET_REGISTRIES" ]; then
        TARGET_REGISTRIES=$TARGET_REGISTRIES,$image_destination
      else
        TARGET_REGISTRIES=$image_destination
      fi
    done < "$file_targets"
    export TARGET_REGISTRIES
    if ! yq -n -o=json '{(strenv(SOURCE_IMAGE)): (strenv(TARGET_REGISTRIES) | split(","))}' > "$file_config"; then
      echo "Failed to generate image config for $path_image_src" >&2
      status_total=$((status_total + 1))
      continue
    fi
    run_image_sync --proc=16 --retries=2 "--auth=$file_auth" "--images=$file_config"
  else
    if [ -z "${DOCKER_MIRROR_REGISTRY_USERNAME:-}" ] || [ -z "${DOCKER_MIRROR_REGISTRY_PASSWORD:-}" ]; then
      echo "DOCKER_MIRROR_REGISTRY_USERNAME and DOCKER_MIRROR_REGISTRY_PASSWORD are required without --file-auth" >&2
      exit 1
    fi
    if [ -z "${DOCKER_REGISTRY_USERNAME:-}" ] || [ -z "${DOCKER_REGISTRY_PASSWORD:-}" ]; then
      echo "DOCKER_REGISTRY_USERNAME and DOCKER_REGISTRY_PASSWORD are required without --file-auth" >&2
      exit 254
    fi
    while IFS="$(printf '\t')" read -r registry_target target_namespace || [ -n "$registry_target" ]; do
      image_destination=$(image_destination_for_target "$registry_target" "$target_namespace")
      export SOURCE_IMAGE=$image_source TARGET_REGISTRY=$registry_target DESTINATION=$image_destination
      if ! yq -n -o=json \
        '{"images": {(strenv(SOURCE_IMAGE)): [strenv(DESTINATION)]}, "auth": {(strenv(TARGET_REGISTRY)): {"username": strenv(DOCKER_MIRROR_REGISTRY_USERNAME), "password": strenv(DOCKER_MIRROR_REGISTRY_PASSWORD)}}} * {"auth": {(strenv(SOURCE_REGISTRY)): {"username": strenv(DOCKER_REGISTRY_USERNAME), "password": strenv(DOCKER_REGISTRY_PASSWORD)}}}' \
        > "$file_config"; then
        echo "Failed to generate image config for $path_image_src" >&2
        status_total=$((status_total + 1))
        continue
      fi
      run_image_sync --proc=16 --retries=2 "--config=$file_config"
    done < "$file_targets"
  fi
done < "$file_names"

exit "$status_total"
