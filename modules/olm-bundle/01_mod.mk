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

# Utility variables
current_makefile = $(lastword $(MAKEFILE_LIST))
current_makefile_directory = $(dir $(current_makefile))
yamlfmt_config := $(current_makefile_directory)/yamlfmt.yaml
comma := ,

base64_wrapped := base64 -w76
ifeq ($(HOST_OS),darwin)
	base64_wrapped := base64 -b76
endif

# Utility functions
for_each_kv = $(foreach item,$2,$(eval $(call $1,$(word 1,$(subst =, ,$(item))),$(word 2,$(subst =, ,$(item))))))
fatal_if_undefined = $(if $(findstring undefined,$(origin $1)),$(error $1 is not set))

# Build up config
olm_bundle_dir := $(bin_dir)/scratch/olm/bundle-$(oci_olm_image_tag)

# Build the olm-to-oci tool
olm_to_oci_dir := $(current_makefile_directory:/=)/olm-to-oci
OLM-TO-OCI := $(CURDIR)/$(bin_dir)/tools/olm-to-oci
NEEDS_OLM-TO-OCI := $(bin_dir)/tools/olm-to-oci
$(NEEDS_OLM-TO-OCI): $(wildcard $(olm_to_oci_dir)/*.go) | $(NEEDS_GO)
	cd $(olm_to_oci_dir) && GOWORK=off GOBIN=$(CURDIR)/$(dir $@) $(GO) install .

# Get all example files
olm_examples := $(wildcard $(olm_example_directory)/*.yaml)

.PHONY: olm-bundle
olm-bundle: $(helm_chart_archive) $(olm_clusterserviceversion_path) | $(NEEDS_HELM) $(NEEDS_YQ) $(NEEDS_OPERATOR-SDK) $(NEEDS_YAMLFMT)
	rm -rf $(olm_bundle_dir) $(oci_layout_path_olm) $(oci_digest_path_olm)
	mkdir -p $(olm_bundle_dir)
	cd $(olm_bundle_dir) && $(HELM) template $(addprefix --values=,$(abspath $(olm_helm_value_path))) $(olm_project_name) $(CURDIR)/$(helm_chart_archive) |\
		$(YQ) 'del(.metadata.annotations["helm.sh/resource-policy"])' |\
		$(YQ) 'del(.metadata.labels["app.kubernetes.io/managed-by"])' |\
		$(YQ) 'del(.metadata.labels["app.kubernetes.io/version"])' |\
		$(YQ) 'del(.metadata.labels["helm.sh/chart"])' |\
		$(YQ) 'del(.metadata.creationTimestamp)' |\
		$(YQ) - $(abspath $(olm_clusterserviceversion_path)) $(abspath $(olm_examples)) $(abspath $(olm_additional_manifests)) |\
		$(OPERATOR-SDK) generate bundle --output-dir . --package $(olm_project_name) --version $(VERSION:v%=%)

	@# Set the previous version in the replaces field, this is required for auto-upgrade to work
	$(YQ) -i '.spec.replaces = "$(olm_project_name).$(olm_replaces_version)"' $(olm_bundle_dir)/manifests/$(olm_project_name).clusterserviceversion.yaml

	@# Set the container image annotation
	$(YQ) -i '.metadata.annotations.containerImage = .spec.install.spec.deployments[0].spec.template.spec.containers[0].image' $(olm_bundle_dir)/manifests/$(olm_project_name).clusterserviceversion.yaml
	$(YQ) -i '.spec.relatedImages = [ .spec.install.spec.deployments[].spec.template.spec.containers[] | {"name": .name, "image": .image} ]' $(olm_bundle_dir)/manifests/$(olm_project_name).clusterserviceversion.yaml

	@# Set the supported OS/Arches based on $(oci_platforms)
	$(YQ) -i --string-interpolation '. * ("$(oci_platforms)" | [ split(",").[] | split("/") | ["operatorframework.io/os.\(.[0])", "operatorframework.io/arch.\(.[1])"] ] | [ .[][] ] | unique | .[] as $$item ireduce({}; . * {"metadata": {"labels": {$$item: "supported"}}}))' $(olm_bundle_dir)/manifests/$(olm_project_name).clusterserviceversion.yaml

	@# Set the openshift version
	$(YQ) -i '.annotations."com.redhat.openshift.versions"="$(olm_openshift_version)"' $(olm_bundle_dir)/metadata/annotations.yaml

	@# Merge in custom annotations
	$(YQ) eval-all -i '. as $$item ireduce ({}; . * $$item )' $(olm_bundle_dir)/metadata/annotations.yaml $(olm_annotations_path)

	@# Copy in scorecard config
	$(if $(olm_scorecard_config_path),mkdir -p $(olm_bundle_dir)/tests/scorecard && cp $(olm_scorecard_config_path) $(olm_bundle_dir)/tests/scorecard/config.yaml)

	@# Set the displayName and description of CRDs
	$(YQ) eval-all -i '.spec.customresourcedefinitions.owned = [ select(.kind == "CustomResourceDefinition") | {"kind": .spec.names.kind$(comma) "name": .metadata.name$(comma) "displayName": .spec.names.kind$(comma) "version": (.spec.versions[] | select(.storage == true) | .name)$(comma)"description": (.spec.versions[] | select(.storage == true) | .schema.openAPIV3Schema.description)} ] | select(fi == 0)' $(olm_bundle_dir)/manifests/$(olm_project_name).clusterserviceversion.yaml $(olm_bundle_dir)/manifests/*.yaml

	@# Use folded style for long lines (lines cannot be longer than 180)
	for file in $$(find $(olm_bundle_dir) -name "*.yaml"); do yq -i '(.. | select(tag == "!!str" and ([split("\n") | .[] | length | select(. > 150)] | length) != 0)) |= . style="folded"' $$file; done

	@# Set the icon in the clusterserviceversion
	$(if $(olm_icon_path),$(YQ) -i '.spec.icon = [{"mediatype": "image/png"$(comma) "base64data": load_str("'<(cat $(olm_icon_path) | $(base64_wrapped))'")}]' $(olm_bundle_dir)/manifests/$(olm_project_name).clusterserviceversion.yaml)

	@# Run through yamlfmt
	$(YAMLFMT) -conf $(yamlfmt_config) $(olm_bundle_dir)/**/*.yaml

	@# Remove the bundle dockerfile
	rm -f $(olm_bundle_dir)/bundle.Dockerfile

.PHONY: oci-build-olm
## Generate OCI directory for OLM bundle
## @category [shared] Build
oci-build-olm: olm-bundle | $(NEEDS_OLM-TO-OCI)
	$(OLM-TO-OCI) $(olm_bundle_dir) $(oci_layout_path_olm)

# $1 upstream repo
# $2 fork
define olm_publish_targets
.PHONY: olm-publish-$(subst /,-,$1)
olm-publish-$(subst /,-,$1): olm-bundle | $(NEEDS_GH) $(NEEDS_YQ) $(bin_dir)/scratch
	rm -rf $(bin_dir)/scratch/git/$2
	mkdir -p $(bin_dir)/scratch/git/$(dir $2)
	$(GH) repo clone $2 $(bin_dir)/scratch/git/$2
	cd $(bin_dir)/scratch/git/$2 && \
		git checkout -B $(VERSION) && \
		mkdir -p operators/$(olm_project_name) && \
		cp -r $(abspath $(olm_bundle_dir)) operators/$(olm_project_name)/$(VERSION) && \
		git add operators/$(olm_project_name)/$(VERSION) && \
		touch operators/$(olm_project_name)/ci.yaml && \
		$(if $(and $(findstring redhat-openshift-ecosystem/certified-operators,$1),$(olm_project_id)), \
			$(YQ) -i '.cert_project_id = "$(olm_project_id)"' operators/$(olm_project_name)/ci.yaml &&) \
		$(YQ) -i '.updateGraph = "semver-mode"' operators/$(olm_project_name)/ci.yaml && \
		git add operators/$(olm_project_name)/ci.yaml && \
		git commit -m "operator $(olm_project_name) ($(VERSION))" && \
		git -c "credential.helper=!$(GH) auth git-credential" push -f origin $(VERSION) && \
		{ $(GH) pr create --repo $1 --head $(firstword $(subst /, ,$2)):$(VERSION) --title "operator $(olm_project_name) ($(VERSION))" --body "Release of $(olm_project_name) - $(VERSION)" ||:; }

olm-publish: olm-publish-$(subst /,-,$1)
endef

$(call for_each_kv,olm_publish_targets,$(olm_publish_repos))

.PHONY: olm-publish
## Publish the OLM bundle to an upstream repo, the GH_TOKEN environment variable
## is required to exist
## @category [shared] Publish
olm-publish:

.PHONY: preflight-scan
## Scan the published image using preflight
## @category [shared] Publish
preflight-scan:

define preflight_scan_targets
.PHONY: preflight-scan-$1
preflight-scan-$1: | $$(NEEDS_PREFLIGHT)
	$$(call fatal_if_undefined,PYXIS_API_TOKEN)
	$$(PREFLIGHT) check container --submit --certification-project-id $2 --pyxis-api-token $$(PYXIS_API_TOKEN) $(firstword $(filter $1:%,$(foreach build_name,$(build_names),$(addsuffix :$(oci_$(build_name)_image_tag),$(oci_$(build_name)_image_name)))))

preflight-scan: preflight-scan-$1
endef

$(call for_each_kv,preflight_scan_targets,$(preflight_container_project_ids))
