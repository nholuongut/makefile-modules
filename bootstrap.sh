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

# This script bootstraps a makefile-module project by setting up the necessary
# files so that all tools are available to run the makefile and download more
# modules if desirable.

# The script is intended to be stand-alone and should download all necessary
# files from github.

# The command line arguments are:
# 1. The destination directory for the new repo

if [ $# -ne 2 ]; then
  echo "Usage: $0 <destination-directory> <profile>"
  exit 1
fi

PROFILE=$2

case $PROFILE in
  "empty") ;;
  "base") ;;
  *)
    echo "Invalid profile. Please use one of the following: empty, base"
    exit 1
    ;;
esac

# If go is not installed, fail
if ! command -v go &> /dev/null; then
  echo "Go is not installed. Please install go before running this script."
  exit 1
fi

DEST_DIR=$1

# Create the destination directory
mkdir -p "${DEST_DIR}"

pushd "${DEST_DIR}" > /dev/null

# If the destination directory is not part of a git repository, fail
if [ ! -d .git ]; then
  echo "The destination directory is not a git repository. Please initialize a git repository before running this script."
  exit 1
fi

bootstrap_hash="652f41ca2a789690977902191af89b423482853f"

# Download the makefile
curl -sSL https://raw.githubusercontent.com/nholuongut/makefile-modules/${bootstrap_hash}/modules/repository-base/base/Makefile -o Makefile

makefile-modules=(go run github.com/cert-manager/makefile-modules@v0.1.0)

"${makefile-modules[@]}" init

essential_modules=(
  "tools"
  "makefile-modules"
)

for module in "${essential_modules[@]}"; do
  "${makefile-modules[@]}" add \
    make/_shared "${module}" \
    https://github.com/nholuongut/makefile-modules.git modules/"${module}" main "${bootstrap_hash}"
done

"${makefile-modules[@]}" sync

make upgrade-makefile-modules

if [ "${PROFILE}" == "base" ]; then
  base_modules=(
    "generate-verify"
    "boilerplate"
    "help"
    "repository-base"
  )

  for module in "${base_modules[@]}"; do
    "${makefile-modules[@]}" add \
      make/_shared "${module}" \
      https://github.com/nholuongut/makefile-modules.git modules/"${module}" main
  done

  make upgrade-makefile-modules
  make generate
fi

popd > /dev/null
