#!/bin/sh

if [ "$#" -ge 1 ]; then
    PROFILE_LOCALIZE="$1"
else
    PROFILE_LOCALIZE="${PROFILE_LOCALIZE:-default}"
fi

echo "Using PROFILE_LOCALIZE=${PROFILE_LOCALIZE}"

SOURCE="$0"
case "$SOURCE" in /*) ;; *) SOURCE="$(pwd)/$SOURCE" ;; esac

while [ -L "$SOURCE" ]; do
    DIR="$(CDPATH= cd -P "$(dirname "$SOURCE")" && pwd)" || exit 1
    TARGET="$(readlink "$SOURCE")" || exit 1
    case "$TARGET" in /*) SOURCE="$TARGET" ;; *) SOURCE="$DIR/$TARGET" ;; esac
done

DIR_BASE="$(CDPATH= cd -P "$(dirname "$SOURCE")" && pwd)" || exit 1
FILE="$DIR_BASE/localize/run-config-mirror-$PROFILE_LOCALIZE.sh"

if [ -f "$FILE" ]; then
    . "$FILE"
else
    echo "No such profile for localize: $PROFILE_LOCALIZE" >&2
    exit 1
fi
