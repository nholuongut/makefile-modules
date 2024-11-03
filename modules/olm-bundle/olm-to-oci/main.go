/*
Copyright 2024 The Nho Luong.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package main

import (
	"archive/tar"
	"bytes"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"

	"github.com/google/go-containerregistry/pkg/crane"
	cranev1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/empty"
	"github.com/google/go-containerregistry/pkg/v1/mutate"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
	yaml "gopkg.in/yaml.v3"
)

func main() {
	// Create function to describe usage
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "%s bundle-path oci-path\n\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "Converts the provided OLM bundle into an OCI directory.\n\n")
		flag.PrintDefaults()
	}

	// Parse flags, we actually have no flags, but this adds `-help`, which is nice
	flag.Parse()

	// Validate we have the correct number of arguments
	args := flag.Args()
	if len(args) < 2 {
		flag.Usage()
		os.Exit(1)
	}

	bundle := args[0]
	oci := args[1]

	image, err := buildImage(bundle)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Could not build image from bundle: %s", err)
		os.Exit(1)
	}

	err = crane.SaveOCI(image, oci)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Could not save OCI directory: %s", err)
		os.Exit(1)
	}

	digest, err := image.Digest()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Could not get image digest: %s", err)
		os.Exit(1)
	}

	err = os.WriteFile(oci+".digests", []byte(digest.String()), 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Could not save OCI digests: %s", err)
		os.Exit(1)
	}
}

// buildImage constructs an image from the provided bundle directory
func buildImage(bundle string) (cranev1.Image, error) {
	layer, err := loadLayer(bundle)
	if err != nil {
		return nil, err
	}

	image, err := mutate.AppendLayers(empty.Image, layer)
	if err != nil {
		return nil, err
	}

	annotations, err := loadAnnotations(bundle)
	if err != nil {
		return nil, err
	}

	image, err = mutate.Config(image, cranev1.Config{Labels: annotations})
	if err != nil {
		return nil, err
	}

	return image, nil
}

// loadLayer will create an image layer from the bundle directory
func loadLayer(bundle string) (cranev1.Layer, error) {
	// Create buffer and tarball writer that will fill the buffer
	var buffer bytes.Buffer
	tw := tar.NewWriter(&buffer)

	// Walk the all the files in the bundle, only keep directories and yaml
	// files
	err := filepath.Walk(bundle, func(target string, info fs.FileInfo, err error) error {
		if err != nil {
			return err
		}

		// Generate tar header - this is not actually used as a smaller header
		// with reproducible values is used, but some of the values are
		// copied from here
		header, err := tar.FileInfoHeader(info, info.Name())
		if err != nil {
			return err
		}

		// Generate a relative name so the tarball does not have the full
		// path
		name, err := filepath.Rel(bundle, target)
		if err != nil {
			return err
		}

		// If the path is not directory or a yaml file, skip it
		if !info.IsDir() {
			if ext := filepath.Ext(name); ext != "yaml" && ext != "yml" {
				return nil
			}
		}

		// Write simplified header, this removes all fields that would cause
		// the build to be non-reproducible (like modtime for example)
		err = tw.WriteHeader(&tar.Header{
			Typeflag: header.Typeflag,
			Name:     name,
			Mode:     header.Mode,
			Linkname: header.Linkname,
			Size:     header.Size,
		})

		if err != nil {
			return err
		}

		// Write the file contents to the tarball
		if !info.IsDir() {
			file, err := os.Open(target)
			if err != nil {
				return err
			}

			defer file.Close()

			_, err = io.Copy(tw, file)
			if err != nil {
				return err
			}
		}

		return nil
	})

	if err != nil {
		return nil, err
	}

	// Flush the writer to the buffer
	if err := tw.Close(); err != nil {
		return nil, err
	}

	// Return layer from tarball
	data := buffer.Bytes()
	return tarball.LayerFromOpener(func() (io.ReadCloser, error) {
		return io.NopCloser(bytes.NewReader(data)), nil
	})
}

// loadAnnotations reads the bundles annotations from metadata/annotations.yaml
func loadAnnotations(bundle string) (map[string]string, error) {
	type Annotations struct {
		Annotations map[string]string `yaml:"annotations"`
	}

	path := filepath.Join(bundle, "metadata", "annotations.yaml")

	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var annotations Annotations
	if err := yaml.Unmarshal(data, &annotations); err != nil {
		return nil, err
	}

	return annotations.Annotations, nil
}
