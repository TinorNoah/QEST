package manifests

import "embed"

// ToolFS embeds TOML tool manifests for self-contained release binaries.
//
//go:embed tools/*.toml
var ToolFS embed.FS
