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

repo_name := test-project

kind_cluster_name := test-project
kind_cluster_config := $(bin_dir)/scratch/kind_cluster.yaml

build_names := manager

go_manager_main_dir := .
go_manager_mod_dir := .
go_manager_ldflags := -X $(repo_name)/pkg/internal/version.AppVersion=$(VERSION) -X $(repo_name)/pkg/internal/version.GitCommit=$(GITCOMMIT)
oci_manager_base_image_flavor := static
oci_manager_image_name := quay.io/cert-manager/test-project
oci_manager_image_tag := $(VERSION)
oci_manager_image_name_development := cert-manager.local/test-project

deploy_name := test-project
deploy_namespace := cert-manager

golangci_lint_config := .golangci.yaml
