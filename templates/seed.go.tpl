{{ $alias := .Aliases.Table .Table.Name -}}
{{- $orig_tbl_name := .Table.Name -}}

var Random{{$alias.UpSingular}} func() *models.{{$alias.UpSingular}}

{{range .Table.ToManyRelationships -}}
{{- $ftable := $.Aliases.Table .ForeignTable -}}
{{- $relAlias := $.Aliases.ManyRelationship .ForeignTable .Name .JoinTable .JoinLocalFKeyName -}}
var {{$relAlias.Local}}Per{{$alias.UpSingular}} int = 1
{{end -}}{{/* range tomany */}}

type rel{{$alias.UpSingular}}InsertOneFunc = func({{if not .NoContext}}ctx context.Context, {{end}}exec boil.ContextExecutor, insert bool, related *models.{{$alias.UpSingular}}) error

type rel{{$alias.UpSingular}}InsertManyFunc = func({{if not .NoContext}}ctx context.Context, {{end}}exec boil.ContextExecutor, insert bool, related ...*models.{{$alias.UpSingular}}) error

func {{$alias.UpSingular}}({{if not .NoContext}}ctx context.Context, {{end}}exec boil.ContextExecutor) error {
	seeded := &filled{}

	_, err := {{$alias.DownSingular}}WithRelationships({{if not .NoContext}}ctx, {{end}}exec, seeded, nil)
	if err != nil {
		return err
	}

	return nil
}

func {{$alias.DownSingular}}WithRelationships({{if not .NoContext}}ctx context.Context, {{end}}exec boil.ContextExecutor, seeded *filled, insertFunc rel{{$alias.UpSingular}}InsertOneFunc) (*models.{{$alias.UpSingular}}, error) {
	o := Random{{$alias.UpSingular}}()
	seeded.{{$alias.UpPlural}} = true

	if insertFunc != nil {
		if err := insertFunc({{if not .NoContext}}ctx, {{end -}} exec, true, o); err != nil {
			return o, fmt.Errorf("Unable to Insert {{$alias.UpSingular}} struct: %w", err)
		}
	} else {
		if err := o.Insert({{if not .NoContext}}ctx, {{end -}} exec, boil.Infer()); err != nil {
			return o, fmt.Errorf("Unable to Insert {{$alias.UpSingular}} struct: %w", err)
		}
	}

	{{range .Table.FKeys -}}
	{{- $ftable := $.Aliases.Table .ForeignTable -}}
	{{- $relAlias := $alias.Relationship .Name -}}
	if !seeded.{{$ftable.UpPlural}} {
		fmt.Println("Setting {{$relAlias.Foreign}} on {{$alias.UpSingular}}")
		rel{{$relAlias.Foreign}}, err := {{$ftable.DownSingular}}WithRelationships({{if not $.NoContext}}ctx, {{end}}exec, seeded, o.Set{{$relAlias.Foreign}})
		if err != nil {
			return o, fmt.Errorf("Unable to get {{$ftable.DownSingular}}WithRelationships: %w", err)
		}
		_ = rel{{$relAlias.Foreign}}
		// if err := o.Set{{$relAlias.Foreign}}({{if not $.NoContext}}ctx, {{end}}exec, true, rel{{$relAlias.Foreign}}); err != nil {
			// return o, fmt.Errorf("Unable to set {{$relAlias.Foreign}} on {{$alias.UpSingular}}: %w", err)
		// }
	}
	{{end}}

	{{range .Table.ToOneRelationships -}}
	{{- $ftable := $.Aliases.Table .ForeignTable -}}
	{{- $relAlias := $ftable.Relationship .Name -}}
	if !seeded.{{$ftable.UpPlural}} {
		fmt.Println("Setting {{$relAlias.Local}} on {{$alias.UpSingular}}")
		rel{{$relAlias.Local}}, err := {{$ftable.DownSingular}}WithRelationships({{if not $.NoContext}}ctx, {{end}}exec, seeded, o.Set{{$relAlias.Local}})
		if err != nil {
			return o, fmt.Errorf("Unable to get {{$ftable.DownSingular}}WithRelationships: %w", err)
		}
		_ = rel{{$relAlias.Local}}
		// if err := o.Set{{$relAlias.Local}}({{if not $.NoContext}}ctx, {{end}}exec, true, rel{{$relAlias.Local}}); err != nil {
			// return o, fmt.Errorf("Unable to set {{$relAlias.Local}} on {{$alias.UpSingular}}: %w", err)
		// }
	}
	{{end}}

	{{range .Table.ToManyRelationships -}}
	{{- $ftable := $.Aliases.Table .ForeignTable -}}
	{{- $relAlias := $.Aliases.ManyRelationship .ForeignTable .Name .JoinTable .JoinLocalFKeyName -}}

	if !seeded.{{$ftable.UpPlural}} {
		fmt.Printf("Adding %d {{$relAlias.Local}} to {{$alias.UpSingular}}\n", {{$relAlias.Local}}Per{{$alias.UpSingular}})
		rel{{$relAlias.Local}} := make(models.{{printf "%sSlice" $ftable.UpSingular}}, {{$relAlias.Local}}Per{{$alias.UpSingular}})
		for i := 0; i < {{$relAlias.Local}}Per{{$alias.UpSingular}}; i++ {
			seededCopy := &filled{}
			*seededCopy = *seeded
			a{{$ftable.UpSingular}}, err := {{$ftable.DownPlural}}WithRelationships({{if not $.NoContext}}ctx, {{end}}exec, seededCopy, o.Add{{$relAlias.Local}})
			if err != nil {
				return o, fmt.Errorf("Unable to get {{$ftable.DownSingular}}WithRelationships: %w", err)
			}
			rel{{$relAlias.Local}}[i] = a{{$ftable.UpSingular}}
		}
		_ = rel{{$relAlias.Local}}
		// if err := o.Add{{$relAlias.Local}}({{if not $.NoContext}}ctx, {{end}}exec, true, rel{{$relAlias.Local}}...); err != nil {
			// return o, fmt.Errorf("Unable to add {{$relAlias.Local}} to {{$alias.UpSingular}}: %w", err)
		// }
	}

	{{end}}{{/* range tomany */}}
	
	return o, nil
}

func {{$alias.DownPlural}}WithRelationships({{if not .NoContext}}ctx context.Context, {{end}}exec boil.ContextExecutor, seeded *filled, insertFunc rel{{$alias.UpSingular}}InsertManyFunc) (*models.{{$alias.UpSingular}}, error) {
	o := Random{{$alias.UpSingular}}()
	seeded.{{$alias.UpPlural}} = true

	if insertFunc != nil {
		if err := insertFunc({{if not .NoContext}}ctx, {{end -}} exec, true, o); err != nil {
			return o, fmt.Errorf("Unable to Insert {{$alias.UpSingular}} struct: %w", err)
		}
	} else {
		if err := o.Insert({{if not .NoContext}}ctx, {{end -}} exec, boil.Infer()); err != nil {
			return o, fmt.Errorf("Unable to Insert {{$alias.UpSingular}} struct: %w", err)
		}
	}

	{{range .Table.FKeys -}}
	{{- $ftable := $.Aliases.Table .ForeignTable -}}
	{{- $relAlias := $alias.Relationship .Name -}}
	if !seeded.{{$ftable.UpPlural}} {
		fmt.Println("Setting {{$relAlias.Foreign}} on {{$alias.UpSingular}}")
		rel{{$relAlias.Foreign}}, err := {{$ftable.DownSingular}}WithRelationships({{if not $.NoContext}}ctx, {{end}}exec, seeded, o.Set{{$relAlias.Foreign}})
		if err != nil {
			return o, fmt.Errorf("Unable to get {{$ftable.DownSingular}}WithRelationships: %w", err)
		}
		_ = rel{{$relAlias.Foreign}}
		// if err := o.Set{{$relAlias.Foreign}}({{if not $.NoContext}}ctx, {{end}}exec, true, rel{{$relAlias.Foreign}}); err != nil {
			// return o, fmt.Errorf("Unable to set {{$relAlias.Foreign}} on {{$alias.UpSingular}}: %w", err)
		// }
	}
	{{end}}

	{{range .Table.ToOneRelationships -}}
	{{- $ftable := $.Aliases.Table .ForeignTable -}}
	{{- $relAlias := $ftable.Relationship .Name -}}
	if !seeded.{{$ftable.UpPlural}} {
		fmt.Println("Setting {{$relAlias.Local}} on {{$alias.UpSingular}}")
		rel{{$relAlias.Local}}, err := {{$ftable.DownSingular}}WithRelationships({{if not $.NoContext}}ctx, {{end}}exec, seeded, o.Set{{$relAlias.Local}})
		if err != nil {
			return o, fmt.Errorf("Unable to get {{$ftable.DownSingular}}WithRelationships: %w", err)
		}
		_ = rel{{$relAlias.Local}}
		// if err := o.Set{{$relAlias.Local}}({{if not $.NoContext}}ctx, {{end}}exec, true, rel{{$relAlias.Local}}); err != nil {
			// return o, fmt.Errorf("Unable to set {{$relAlias.Local}} on {{$alias.UpSingular}}: %w", err)
		// }
	}
	{{end}}

	{{range .Table.ToManyRelationships -}}
	{{- $ftable := $.Aliases.Table .ForeignTable -}}
	{{- $relAlias := $.Aliases.ManyRelationship .ForeignTable .Name .JoinTable .JoinLocalFKeyName -}}

	if !seeded.{{$ftable.UpPlural}} {
		fmt.Printf("Adding %d {{$relAlias.Local}} to {{$alias.UpSingular}}\n", {{$relAlias.Local}}Per{{$alias.UpSingular}})
		rel{{$relAlias.Local}} := make(models.{{printf "%sSlice" $ftable.UpSingular}}, {{$relAlias.Local}}Per{{$alias.UpSingular}})
		for i := 0; i < {{$relAlias.Local}}Per{{$alias.UpSingular}}; i++ {
			seededCopy := &filled{}
			*seededCopy = *seeded
			a{{$ftable.UpSingular}}, err := {{$ftable.DownPlural}}WithRelationships({{if not $.NoContext}}ctx, {{end}}exec, seededCopy, o.Add{{$relAlias.Local}})
			if err != nil {
				return o, fmt.Errorf("Unable to get {{$ftable.DownSingular}}WithRelationships: %w", err)
			}
			rel{{$relAlias.Local}}[i] = a{{$ftable.UpSingular}}
		}
		_ = rel{{$relAlias.Local}}
		// if err := o.Add{{$relAlias.Local}}({{if not $.NoContext}}ctx, {{end}}exec, true, rel{{$relAlias.Local}}...); err != nil {
			// return o, fmt.Errorf("Unable to add {{$relAlias.Local}} to {{$alias.UpSingular}}: %w", err)
		// }
	}

	{{end}}{{/* range tomany */}}
	
	return o, nil
}










// This is to force strconv to be used. Without it, it causes an error because strconv is imported by ALL the drivers
var _ = strconv.IntSize

// {{$alias.DownSingular}} is here to prevent erros due to driver "BasedOnType" imports.
type {{$alias.DownSingular}} struct {
	{{- range $column := .Table.Columns -}}
	{{- $colAlias := $alias.Column $column.Name -}}
	{{- $orig_col_name := $column.Name -}}
	{{if ignore $orig_tbl_name $orig_col_name $.TagIgnore -}}
	{{$colAlias}} {{$column.Type}} `{{generateIgnoreTags $.Tags}}boil:"{{$column.Name}}" json:"-" toml:"-" yaml:"-"`
	{{else if eq $.StructTagCasing "title" -}}
	{{$colAlias}} {{$column.Type}} `{{generateTags $.Tags $column.Name}}boil:"{{$column.Name}}" json:"{{$column.Name | titleCase}}{{if $column.Nullable}},omitempty{{end}}" toml:"{{$column.Name | titleCase}}" yaml:"{{$column.Name | titleCase}}{{if $column.Nullable}},omitempty{{end}}"`
	{{else if eq $.StructTagCasing "camel" -}}
	{{$colAlias}} {{$column.Type}} `{{generateTags $.Tags $column.Name}}boil:"{{$column.Name}}" json:"{{$column.Name | camelCase}}{{if $column.Nullable}},omitempty{{end}}" toml:"{{$column.Name | camelCase}}" yaml:"{{$column.Name | camelCase}}{{if $column.Nullable}},omitempty{{end}}"`
	{{else -}}
	{{$colAlias}} {{$column.Type}} `{{generateTags $.Tags $column.Name}}boil:"{{$column.Name}}" json:"{{$column.Name}}{{if $column.Nullable}},omitempty{{end}}" toml:"{{$column.Name}}" yaml:"{{$column.Name}}{{if $column.Nullable}},omitempty{{end}}"`
	{{end -}}
	{{end -}}
}