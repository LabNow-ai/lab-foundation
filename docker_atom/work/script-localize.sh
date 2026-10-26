#!/bin/bash

# Set PROFILE_LOCALIZE based on input or environment variable
if [ $# -ge 1 ]; then
    PROFILE_LOCALIZE="$1"
else
    PROFILE_LOCALIZE="${PROFILE_LOCALIZE:-"default"}"
fi

echo "Using PROFILE_LOCALIZE=${PROFILE_LOCALIZE}"

# Define the file path based on the PROFILE_LOCALIZE variable
# reference: https://github.com/RubyMetric/chsrc/blob/main/src/chsrc.c
DIR_BASE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FILE="${DIR_BASE}/localize/run-config-mirror-${PROFILE_LOCALIZE}.sh"

# Check if the file exists
if [ -f "$FILE" ]; then
    . "$FILE"
else
    echo "No such profile for localize: $PROFILE_LOCALIZE" >&2
    exit 1
fi
