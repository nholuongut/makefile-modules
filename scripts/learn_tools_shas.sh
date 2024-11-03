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

# This script updates the sha values for the tools. It is intended
# to be run after updating the version of a tool in the tools Makefile
# module.

script_dir=$(dirname "$(realpath "$0")")

tool_targets=("$@")
if [ ${#tool_targets[@]} -eq 0 ]; then
    echo "Usage: $0 <tool-target>..."
    echo "Example 1: $0 tools vendor-go"
    echo "Example 2: $0 _bin/tools/helm _bin/tools/kubectl"
    exit 1
fi

# Create a temporary directory to store the downloaded tools
tmp_dir=$(mktemp -d)
trap '{ rm -rf "$tmp_dir"; echo "> Deleted temp dir $tmp_dir"; }' EXIT

# Copy the makefiles to the temporary directory
cp "${script_dir}/learn_tools_shas.helper.mk" "${tmp_dir}/learn_tools_shas.helper.mk"
cp -r "${script_dir}/../modules/tools/." "${tmp_dir}/tools"

pushd "${tmp_dir}" > /dev/null

learn_file="learn_tools_file"
echo -n "" > "${learn_file}"

# Loop over each OS and ARCH combination and download the tools
for os_arch in linux/amd64 linux/arm64 darwin/amd64 darwin/arm64; do
    os=$(echo "${os_arch}" | cut -d'/' -f1)
    arch=$(echo "${os_arch}" | cut -d'/' -f2)

    # Download the tools
    make -j \
        HOST_OS="${os}" \
        HOST_ARCH="${arch}" \
        LEARN_FILE="${learn_file}" \
        -f ./learn_tools_shas.helper.mk "${tool_targets[@]}"
done

cat "${learn_file}"

# see https://stackoverflow.com/a/53408233
sed_args='-i'''
if [[ $(uname -s) == "Darwin" ]]; then
	sed_args=(-i '')
fi

while read -r replace; do \
    sed "${sed_args[@]}" "$replace" "${script_dir}/../modules/tools/00_mod.mk";
done <"${learn_file}"

popd
