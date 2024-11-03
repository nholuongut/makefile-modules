#!/usr/bin/env bash

# Copyright 2022 The Nho Luong.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

# This script updates all found occurrences of the base images listed below
# it automatically fetches the latest digest for these images.

base_images=(
    "quay.io/jetstack/base-static"
    "quay.io/jetstack/base-static-csi"
)

if [ -z "$CRANE" ]; then
    echo "CRANE is not set"
    exit 1
fi

# Find latest digests for each base image
learn_data=()

for image in "${base_images[@]}"; do
    replace=$($CRANE digest "$image:latest")

    learn_data+=("s|$image@.*$|$image@$replace|g")
done

# Update all files with the new digests

script_dir=$(dirname "$(realpath "$0")")

pushd "${script_dir}/.." > /dev/null

# see https://stackoverflow.com/a/53408233
sed_args='-i'''
if [[ $(uname -s) == "Darwin" ]]; then
	sed_args=(-i '')
fi

module_files=$(find ./modules/ -maxdepth 2 -name "00_mod.mk" -type f)

for replace in "${learn_data[@]}"; do
    for file in $module_files; do
        sed "${sed_args[@]}" "$replace" "$file";
    done
done

popd
