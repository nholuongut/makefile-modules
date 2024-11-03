# Copyright 2023 The Nho Luong.
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

# Some modules build their dependencies from variables, we want these to be 
# evaluated at the last possible moment. For this we use second expansion to 
# re-evaluate the generate and verify targets a second time.
#
# See https://www.gnu.org/software/make/manual/html_node/Secondary-Expansion.html
.SECONDEXPANSION:

# For details on some of these "prelude" settings, see:
# https://clarkgrubb.com/makefile-style-guide
MAKEFLAGS += --warn-undefined-variables --no-builtin-rules
SHELL := /usr/bin/env bash
.SHELLFLAGS := -uo pipefail -c
.DEFAULT_GOAL := help
.DELETE_ON_ERROR:
.SUFFIXES:
FORCE:

bin_dir := _bin
$(bin_dir) $(bin_dir)/scratch:
	mkdir -p $@

HOST_OS := unused
HOST_ARCH := unused

include modules/tools/00_mod.mk

.PHONY: print-kind-version
print-kind-version:
	@echo $(KIND_VERSION)
