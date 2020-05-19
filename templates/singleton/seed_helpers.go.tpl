type filled struct {
	{{range $table := .Tables -}}
	{{ $alias := $.Aliases.Table $table.Name -}}
	{{$alias.UpPlural}} bool
	{{end -}}
}

func (f *filled) copy() *filled {
	copy := &filled{}
	*copy = *f
	return copy
}