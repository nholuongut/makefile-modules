# OLM Bundle

This is the boilerplate for the OLM bundle, it contains the config that is used
to generate an OLM bundle. 

## Bundle generation

The OLM bundle is generated using the existing Helm chart in the repo. The chart
is build then ran through `helm template`, optionally using a values file for 
specific configuration. 

The manifests produced by `helm template` are merged with a
`clusterresourceversion.yaml` file and run through the 
`operator-sdk generate bundle` command.

Additional mutations are then applied for convenience, for example adding the 
`containerImage` annotation based of the generated manifests.

## Layout

The bundle directory is laid out in the rough structure of the final OLM bundle.
The files in the folder are used as a basis for generating the OLM bundle and
will not appear in the final bundle exactly as written.

```
bundle/
├─ manifests/
│   ├─ $(deploy_name).clusterresourceversion.yaml [required]
│   └─ additional yaml files                      [optional]
│  metadata/
│   └─ annotations.yaml                           [optional]
│  tests/
│   └─ scorecard/
│       └─ config.yaml                            [optional]
│  examples/
│   └─ example yaml files                         [optional]
├─ icon.png                                       [optional]
├─ values.yaml                                    [optional]
└─ README.md
```

### `bundle/manifests/$(deploy_name).clusterresourceversion.yaml`

This file us used as the basis for the final ClusterResourceVersion, it should
not contain any Kubernetes resources as these are added during the bundle
generation process.

The file should contain descriptions and metadata relating to the bundle only.

### `bundle/metadata/annotations.yaml`

This optional file is merged with the generated `annotations.yaml` file. This is
a way for adding additional annotations to the bundle.

### `bundle/tests/scorecard/config.yaml`

The scorecard config for testing the bundle, see 
https://sdk.operatorframework.io/docs/testing-operators/scorecard/ for more 
information.

### `bundle/icon.png`

The icon used when the bundle appears on listings. This functionally the same as 
defining `.spec.icon.base64data` in the clusterresourceversion file, but as this
field is often very large it makes sense to have it as a separate file.

### `bundle/values.yaml`

The values used when `Helm` is used to generate the bundle manifests. This
allows the bundle to have specific config defaults.

### `bundle/examples/*.yaml`

Any examples to include in the OLM bundle, the examples are used when listed on operator-hub. You can have a maximum of
one example per CRD.

### `bundle/README.md`

This file.