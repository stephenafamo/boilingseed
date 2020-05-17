type filled struct {
	{{range $table := .Tables -}}
	{{ $alias := $.Aliases.Table $table.Name -}}
	{{$alias.UpPlural}} bool
	{{end -}}
}