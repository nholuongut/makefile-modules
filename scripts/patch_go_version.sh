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

# This script detects patch version updates for Go and updates the vendored
# Go version in the tools Makefile module. It also updates the SHA256 checksum
# for the vendored Go download.

tools_makefile=../modules/tools/00_mod.mk

script_dir=$(dirname "$(realpath "$0")")

# Create a temporary directory to store the downloaded go version json file
tmp_dir=$(mktemp -d)
trap '{ rm -rf "$tmp_dir"; echo "> Deleted temp dir $tmp_dir"; }' EXIT

# Download version data
curl --silent --show-error --fail --location --retry 10 --retry-connrefused https://go.dev/dl/?mode=json > "${tmp_dir}/version.json"

LOCAL_VERSION=$(<"${script_dir}/${tools_makefile}" grep "VENDORED_GO_VERSION := " | sed "s/VENDORED_GO_VERSION := //")

echo "current go version is $LOCAL_VERSION"

MAJOR_MINOR_VERSION=$(echo "$LOCAL_VERSION" | grep -Eo "[0-9]+.[0-9]+")

NEW_VERSION=$(<"${tmp_dir}/version.json" jq -r ".[] | select(.version? | match(\"$MAJOR_MINOR_VERSION.*\")) | .version | sub(\"go\";\"\")")

# Don't want to update a minor version - only want to update patch versions!
if [[ $NEW_VERSION == "" ]]; then
	echo "failed to fetch the latest version of go $MAJOR_MINOR_VERSION.*"
	echo "this could mean the go version is very old or that go versioning has changed"
	echo "this is likely to require manual intervention"
	exit 1
fi

# Check if there's nothing to do
if [[ "$NEW_VERSION" == "$LOCAL_VERSION" ]]; then
	echo "go version is up to date"
	exit 0
fi

echo "updating go version to $NEW_VERSION in $tools_makefile"

# see https://stackoverflow.com/a/53408233
sed_args='-i'''
if [[ $(uname -s) == "Darwin" ]]; then
	sed_args=(-i '')
fi

sed "${sed_args[@]}" "s/^VENDORED_GO_VERSION := $LOCAL_VERSION$/VENDORED_GO_VERSION := $NEW_VERSION/" "${script_dir}/${tools_makefile}"

echo "update go sha"

"${script_dir}/learn_tools_shas.sh" vendor-go
