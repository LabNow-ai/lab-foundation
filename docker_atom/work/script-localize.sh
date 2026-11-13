#!/bin/sh
# Usage: ./script-localize.sh [profile]
#        source ./script-localize.sh [profile] (Bash; /bin/sh supports direct execution)

PROFILE_LOCALIZE="${1-${PROFILE_LOCALIZE:-default}}"
SOURCE="${BASH_SOURCE:-$0}"
DIR_BASE="$(CDPATH= cd -P "$(dirname "$(readlink -f "$SOURCE")")" && pwd)" || {
    echo "Cannot locate script directory" >&2
    return 1 2>/dev/null || exit 1
}

echo "Using PROFILE_LOCALIZE=${PROFILE_LOCALIZE}"

FILE="$DIR_BASE/localize/run-config-mirror-$PROFILE_LOCALIZE.sh"

[ -f "$FILE" ] || {
    echo "No such profile for localize: $PROFILE_LOCALIZE" >&2
    return 1 2>/dev/null || exit 1
}
. "$FILE"
