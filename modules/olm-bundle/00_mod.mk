# Copyright 2024 The Nho Luong.
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

# Utility functions
fatal_if_undefined = $(if $(findstring undefined,$(origin $1)),$(error $1 is not set))

# Utility variables
current_makefile := $(lastword $(MAKEFILE_LIST))
current_makefile_directory := $(dir $(current_makefile))
olm_base_dir := $(current_makefile_directory)/base

ifdef deploy_name
# Name of the project, this goes in the PROJECT file as well as getting used.
# $(deploy_name) is usually a sane default for this value
olm_project_name ?= $(deploy_name)
endif

$(call fatal_if_undefined,olm_project_name)

# Minimum openshift version we support
olm_openshift_version ?= v4.6

# A mapping of git repos to push to when publishing, OLMs are published by PRing
# into a RedHat repo.
#
# For example, to publish to the certified-operators repos you may do this:
#   olm_publish_repos += redhat-openshift-ecosystem/certified-operators=jetstack/certified-operators
#
# Where the value on the left is the repo to PR into, and the one on the right is
# where to push the changes to PR from
olm_publish_repos ?=

# Project ID is the components ID if publishing to the RedHat certified operators
# program
olm_project_id ?=

# Used for handling auto-upgrade, the version that this release is replacing
olm_replaces_version ?= $(shell git describe --tags --always --match='v*' --abbrev=0 --exclude $(VERSION))

# OLMs are built as images, so can be pushed to image registries. We default the
# tag to the version.
#
# If you wish to push to an OCI registry this can be done by setting
# oci_olm_image_name to the name of the repository
oci_olm_image_tag ?= $(VERSION)

# When publishing a certified operator you must submit a preflight scan, this
# variable maps images to the IDs to use when submitting preflight scan results
# For example:
#   preflight_container_project_ids += registry.venafi.cloud/public/venafi-images/vcp-operator=123456abcdef123456abcde
#
# If left unset, no scans will be submitted
preflight_container_project_ids ?=

# The example directory is used to find CRD examples, this is used to create the
# alm-examples annotation in the clusterserviceversion

# Base directory for OLM bundle
olm_bundle_base := bundle
olm_manifests_base := $(olm_bundle_base)/manifests
olm_metadata_base := $(olm_bundle_base)/metadata
olm_scorecard_base := $(olm_bundle_base)/tests/scorecard
olm_example_directory ?= $(olm_bundle_base)/examples

# Some files are optional, so we use wildcard to not error if they do not exist
olm_clusterserviceversion_path ?= $(olm_manifests_base)/$(deploy_name).clusterserviceversion.yaml
olm_additional_manifests ?= $(filter-out $(olm_clusterserviceversion_path),$(wildcard $(olm_manifests_base)/*.yaml))
olm_annotations_path ?= $(wildcard $(olm_metadata_base)/annotations.yaml)
olm_scorecard_config_path ?= $(wildcard $(olm_scorecard_base)/config.yaml)
olm_icon_path ?= $(wildcard $(olm_bundle_base)/icon.png)
olm_helm_value_path ?= $(wildcard $(olm_bundle_base)/values.yaml $(olm_bundle_base)/values.yml)

# Validate
$(call fatal_if_undefined,oci_olm_image_tag)

# Add OLM as a push target to the oci-publish module
ifdef oci_olm_image_name
push_names += olm
endif

oci_digest_path_olm := $(bin_dir)/scratch/image/oci-layout-olm.$(oci_olm_image_tag).digests
oci_layout_path_olm := $(bin_dir)/scratch/image/oci-layout-olm.$(oci_olm_image_tag)

.PHONY: generate-olm-project
generate-olm-project: | $$(NEEDS_YQ)
	cp -r $(olm_base_dir)/. ./
	$(YQ) -i  '.projectName = "$(deploy_name)"' PROJECT

shared_generate_targets += generate-olm-project

