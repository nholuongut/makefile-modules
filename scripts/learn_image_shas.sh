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

# This script updates the sha values for the images defined in the Makefiles
# specified below. It is intended to be run after updating the tag of an image
# in one of these Makefiles.

image_makefiles=(
    "../modules/cert-manager/00_mod.mk"    
)

script_dir=$(dirname "$(realpath "$0")")

pushd "${script_dir}" > /dev/null
images_amd64=$(make -s -f ./learn_image_shas.helper.mk print-images-amd64 image_makefiles="${image_makefiles[*]}")
images_arm64=$(make -s -f ./learn_image_shas.helper.mk print-images-arm64 image_makefiles="${image_makefiles[*]}")

if [ -z "$CRANE" ]; then
    echo "CRANE is not set"
    exit 1
fi

learn_data=()

for image in $images_amd64; do
    image_no_digest=$(echo -n "$image" | cut -d@ -f1)
    find=$(echo -n "$image" | cut -d@ -f2)
    replace=$($CRANE digest --platform "linux/amd64" "$image_no_digest")

    if [ "$find" == "$replace" ]; then
        continue
    fi

    learn_data+=("s|$find|$replace|g")
done

for image in $images_arm64; do
    image_no_digest=$(echo -n "$image" | cut -d@ -f1)
    find=$(echo -n "$image" | cut -d@ -f2)
    replace=$($CRANE digest --platform "linux/arm64" "$image_no_digest")

    if [ "$find" == "$replace" ]; then
        continue
    fi

    learn_data+=("s|$find|$replace|g")
done

# see https://stackoverflow.com/a/53408233
sed_args='-i'''
if [[ $(uname -s) == "Darwin" ]]; then
	sed_args=(-i '')
fi

for replace in "${learn_data[@]}"; do
    for file in "${image_makefiles[@]}"; do
        sed "${sed_args[@]}" "$replace" "$file";
    done
done
popd
