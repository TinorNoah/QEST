package main

import (
	"strings"
	"testing"
)

func TestLoadToolManifests(t *testing.T) {
	tools, err := loadToolManifests("../../manifests/tools")
	if err != nil {
		t.Fatalf("expected manifests to load, got error: %v", err)
	}
	if len(tools) == 0 {
		t.Fatal("expected at least one manifest")
	}
}

func TestValidateToolManifestsDuplicateID(t *testing.T) {
	tools := []toolManifest{
		{
			ID:               "zsh",
			Category:         "shell_env",
			Tier:             "core",
			ValidationStatus: "validated",
			InstallSource: map[string]string{
				"ubuntu": "native",
				"fedora": "native",
				"arch":   "native",
			},
			PackageName: map[string]string{
				"ubuntu": "zsh",
				"fedora": "zsh",
				"arch":   "zsh",
			},
		},
		{
			ID:               "zsh",
			Category:         "shell_env",
			Tier:             "core",
			ValidationStatus: "validated",
			InstallSource: map[string]string{
				"ubuntu": "native",
				"fedora": "native",
				"arch":   "native",
			},
			PackageName: map[string]string{
				"ubuntu": "zsh",
				"fedora": "zsh",
				"arch":   "zsh",
			},
		},
	}

	err := validateToolManifests(tools)
	if err == nil {
		t.Fatal("expected duplicate id error")
	}
	if !strings.Contains(err.Error(), "duplicate tool id") {
		t.Fatalf("expected duplicate id error, got: %v", err)
	}
}
