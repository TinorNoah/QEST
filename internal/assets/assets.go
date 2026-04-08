package assets

import _ "embed"

//go:embed defaults/.zshrc
var DefaultZshrc string

//go:embed defaults/starship.toml
var DefaultStarship string
