{{ $alias := .Aliases.Table .Table.Name -}}
{{- $orig_tbl_name := .Table.Name -}}

type rel{{$alias.UpSingular}}InsertOneFunc = func({{if not .NoContext}}ctx context.Context, {{end}}exec boil.ContextExecutor, insert bool, related *models.{{$alias.UpSingular}}) error

type rel{{$alias.UpSingular}}InsertManyFunc = func({{if not .NoContext}}ctx context.Context, {{end}}exec boil.ContextExecutor, insert bool, related ...*models.{{$alias.UpSingular}}) error

// Random{{$alias.UpSingular}} creates a random models.{{$alias.UpSingular}}
// It does not need to add relationships.
// Can be set by an external package for better control over seeding
var Random{{$alias.UpSingular}} = func() (*models.{{$alias.UpSingular}}, error){
	o := &models.{{$alias.UpSingular}}{}
	seed := randomize.NewSeed()
	err := randomize.Struct(seed, o, {{$alias.DownSingular}}DBTypes, true, {{$alias.DownSingular}}ColumnsWithDefault...)

	return o, err
}

{{range .Table.ToManyRelationships -}}
{{- $ftable := $.Aliases.Table .ForeignTable -}}
{{- $relAlias := $.Aliases.ManyRelationship .ForeignTable .Name .JoinTable .JoinLocalFKeyName -}}
var {{$relAlias.Local}}Per{{$alias.UpSingular}} int = 1
{{end -}}{{/* range tomany */}}

var (
	{{$alias.DownSingular}}ColumnsWithDefault    = []string{{"{"}}{{.Table.Columns | filterColumnsByDefault true | columnNames | stringMap .StringFuncs.quoteWrap | join ","}}{{"}"}}
	{{$alias.DownSingular}}DBTypes = map[string]string{{"{"}}{{range $i, $col := .Table.Columns -}}{{- if ne $i 0}},{{end}}`{{$alias.Column $col.Name}}`: `{{$col.DBType}}`{{end}}{{"}"}}
	_ = bytes.MinRead
)

func {{$alias.UpPlural}}({{if not .NoContext}}ctx context.Context, {{end}}exec boil.ContextExecutor, amount int) error {
	for i := 0; i < amount; i++ {
		err := {{$alias.UpSingular}}({{if not .NoContext}}ctx, {{end}}exec)
		if err != nil {
			return err
		}
	}

	return nil
}

func {{$alias.UpSingular}}({{if not .NoContext}}ctx context.Context, {{end}}exec boil.ContextExecutor) error {
	seeded := &filled{}

	_, err := {{$alias.DownSingular}}WithRelationships({{if not .NoContext}}ctx, {{end}}exec, seeded, nil)
	if err != nil {
		return err
	}

	return nil
}

func {{$alias.DownSingular}}WithRelationships({{if not .NoContext}}ctx context.Context, {{end}}exec boil.ContextExecutor, seeded *filled, insertFunc rel{{$alias.UpSingular}}InsertOneFunc) (*models.{{$alias.UpSingular}}, error) {
	if Random{{$alias.UpSingular}} == nil {
		return nil, fmt.Errorf("Random{{$alias.UpSingular}}() is nil")
	}
	o, err := Random{{$alias.UpSingular}}()
	if err != nil {
		return o, fmt.Errorf("Unable to get Random{{$alias.UpSingular}}: %w", err)
	}

	if insertFunc != nil {
		if err := insertFunc({{if not .NoContext}}ctx, {{end -}} exec, true, o); err != nil {
			return o, fmt.Errorf("Unable to Insert {{$alias.UpSingular}} struct: %w", err)
		}
	} else {
		if err := o.Insert({{if not .NoContext}}ctx, {{end -}} exec, boil.Infer()); err != nil {
			return o, fmt.Errorf("Unable to Insert {{$alias.UpSingular}} struct: %w", err)
		}
	}

	
	return o, addRelationshipsTo{{$alias.UpSingular}}({{if not .NoContext}}ctx, {{end}}exec, seeded, o)
}

func {{$alias.DownPlural}}WithRelationships({{if not .NoContext}}ctx context.Context, {{end}}exec boil.ContextExecutor, seeded *filled, insertFunc rel{{$alias.UpSingular}}InsertManyFunc) (*models.{{$alias.UpSingular}}, error) {
	if Random{{$alias.UpSingular}} == nil {
		return nil, fmt.Errorf("Random{{$alias.UpSingular}}() is nil")
	}
	o, err := Random{{$alias.UpSingular}}()
	if err != nil {
		return o, fmt.Errorf("Unable to get Random{{$alias.UpSingular}}: %w", err)
	}

	if insertFunc != nil {
		if err := insertFunc({{if not .NoContext}}ctx, {{end -}} exec, true, o); err != nil {
			return o, fmt.Errorf("Unable to Insert {{$alias.UpSingular}} struct: %w", err)
		}
	} else {
		if err := o.Insert({{if not .NoContext}}ctx, {{end -}} exec, boil.Infer()); err != nil {
			return o, fmt.Errorf("Unable to Insert {{$alias.UpSingular}} struct: %w", err)
		}
	}

	
	return o, addRelationshipsTo{{$alias.UpSingular}}({{if not .NoContext}}ctx, {{end}}exec, seeded, o)
}

func addRelationshipsTo{{$alias.UpSingular}}({{if not .NoContext}}ctx context.Context, {{end}}exec boil.ContextExecutor, seeded *filled, o *models.{{$alias.UpSingular}}) error {
	seeded.{{$alias.UpPlural}} = true

	{{range .Table.FKeys -}}
	{{- $ftable := $.Aliases.Table .ForeignTable -}}
	{{- $relAlias := $alias.Relationship .Name -}}
	if !seeded.{{$ftable.UpPlural}} {
		fmt.Println("Setting {{$relAlias.Foreign}} on {{$alias.UpSingular}}")
		_, err := {{$ftable.DownSingular}}WithRelationships({{if not $.NoContext}}ctx, {{end}}exec, seeded, o.Set{{$relAlias.Foreign}})
		if err != nil {
			return fmt.Errorf("Unable to get {{$ftable.DownSingular}}WithRelationships: %w", err)
		}
	}
	{{end}}

	{{range .Table.ToOneRelationships -}}
	{{- $ftable := $.Aliases.Table .ForeignTable -}}
	{{- $relAlias := $ftable.Relationship .Name -}}
	if !seeded.{{$ftable.UpPlural}} {
		fmt.Println("Setting {{$relAlias.Local}} on {{$alias.UpSingular}}")
		_, err := {{$ftable.DownSingular}}WithRelationships({{if not $.NoContext}}ctx, {{end}}exec, seeded, o.Set{{$relAlias.Local}})
		if err != nil {
			return fmt.Errorf("Unable to get {{$ftable.DownSingular}}WithRelationships: %w", err)
		}
	}
	{{end}}

	{{range .Table.ToManyRelationships -}}
	{{- $ftable := $.Aliases.Table .ForeignTable -}}
	{{- $relAlias := $.Aliases.ManyRelationship .ForeignTable .Name .JoinTable .JoinLocalFKeyName -}}

	if !seeded.{{$ftable.UpPlural}} {
		var err error
		if Add{{$relAlias.Local}}To{{$alias.UpSingular}} != nil {
			err = Add{{$relAlias.Local}}To{{$alias.UpSingular}}(ctx, exec, o, {{$relAlias.Local}}Per{{$alias.UpSingular}})
		} else {
			err = generateAdd{{$relAlias.Local}}To{{$alias.UpSingular}}Func(seeded.copy())(ctx, exec, o, {{$relAlias.Local}}Per{{$alias.UpSingular}})
		}
		if err != nil {
			return fmt.Errorf("Unable to add {{$relAlias.Local}} To {{$alias.UpSingular}}: %w", err)
		}
	}

	{{end}}{{/* range tomany */}}
	
	return nil
}

{{range .Table.ToManyRelationships -}}
{{- $ftable := $.Aliases.Table .ForeignTable -}}
{{- $relAlias := $.Aliases.ManyRelationship .ForeignTable .Name .JoinTable .JoinLocalFKeyName -}}

// Add{{$relAlias.Local}}To{{$alias.UpSingular}} creates multiple random models.{{$relAlias.Local}},
// adds them to the given *models.{{$alias.UpSingular}}
// and then INSERTS them into the DB
// NOTE: The *models.{{$alias.UpSingular}} passed to this function would have already been inserted in the DB
var Add{{$relAlias.Local}}To{{$alias.UpSingular}} add{{$relAlias.Local}}To{{$alias.UpSingular}}Func
type add{{$relAlias.Local}}To{{$alias.UpSingular}}Func = func(ctx context.Context, exec boil.ContextExecutor, o *models.{{$alias.UpSingular}}, amount int) error

func generateAdd{{$relAlias.Local}}To{{$alias.UpSingular}}Func(seeded *filled) add{{$relAlias.Local}}To{{$alias.UpSingular}}Func {
	return func(ctx context.Context, exec boil.ContextExecutor, o *models.{{$alias.UpSingular}}, amount int) error {
		fmt.Printf("Adding %d {{$relAlias.Local}} to {{$alias.UpSingular}}\n", {{$relAlias.Local}}Per{{$alias.UpSingular}})
		for i := 0; i < {{$relAlias.Local}}Per{{$alias.UpSingular}}; i++ {
			_, err := {{$ftable.DownPlural}}WithRelationships({{if not $.NoContext}}ctx, {{end}}exec, seeded.copy(), o.Add{{$relAlias.Local}})
			if err != nil {
				return fmt.Errorf("Unable to get {{$ftable.DownSingular}}WithRelationships: %w", err)
			}
		}
		return nil
	}
}

{{end}}{{/* range tomany */}}










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