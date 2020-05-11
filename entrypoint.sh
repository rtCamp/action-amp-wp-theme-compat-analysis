#!/usr/bin/env bash

set -ex

# custom path for files to override default files
custom_path="$GITHUB_WORKSPACE/main/.github/amp-analysis"
main_script="/main.sh"

if [[ -d "$custom_path" ]]; then
    chown -R root: "$custom_path/"
    rsync -av "$custom_path/" /
fi

bash "$main_script" "$@"
