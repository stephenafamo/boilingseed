{{ $alias := .Aliases.Table .Table.Name -}}
{{- $orig_tbl_name := .Table.Name -}}

var (
	{{$alias.DownSingular}}ColumnsWithDefault    = []string{{"{"}}{{.Table.Columns | filterColumnsByDefault true | columnNames | stringMap .StringFuncs.quoteWrap | join ","}}{{"}"}}
	{{$alias.DownSingular}}DBTypes = map[string]string{{"{"}}{{range $i, $col := .Table.Columns -}}{{- if ne $i 0}},{{end}}`{{$alias.Column $col.Name}}`: `{{$col.DBType}}`{{end}}{{"}"}}
	_ = bytes.MinRead
)

// Random{{$alias.UpSingular}} creates a random models.{{$alias.UpSingular}}
// It does not need to add relationships.
// Can be set by an external package for better control over seeding
var Random{{$alias.UpSingular}} = func() (*models.{{$alias.UpSingular}}, error){
	o := &models.{{$alias.UpSingular}}{}
	seed := randomize.NewSeed()
	err := randomize.Struct(seed, o, {{$alias.DownSingular}}DBTypes, true, {{$alias.DownSingular}}ColumnsWithDefault...)

	return o, err
}

// After{{$alias.UpSingular}}Added is called after a models.{{$alias.UpSingular}}
// is added. Can be set by an external package for better control over seeding
var After{{$alias.UpSingular}}Added = func(*models.{{$alias.UpSingular}}) error {
	return nil
}

func seed{{$alias.UpPlural}}(ctx context.Context, exec boil.ContextExecutor) error {
	fmt.Println("Adding {{$alias.UpPlural}}")
	{{$alias.UpPlural}}ToAdd := Min{{$alias.UpPlural}}ToSeed

	{{range .Table.FKeys -}}
	{{ $ftable := $.Aliases.Table .ForeignTable -}}
	{{$ftable.DownPlural}}, err := models.{{$ftable.UpPlural}}().All({{if not $.NoContext}}ctx, {{end}}exec)
	if err != nil {
		return fmt.Errorf("error getting {{$ftable.DownPlural}}: %w", err)
	}
	{{end}}
	

	{{range $tableIn := $.Tables -}}
	{{ $aliasIn := $.Aliases.Table $tableIn.Name -}}

	{{range $rel := $tableIn.ToManyRelationships -}}
	{{if and (not $rel.ToJoinTable) (eq $.Table.Name $rel.ForeignTable) }}

	{{- $ftable := $.Aliases.Table $rel.ForeignTable -}}
	{{- $relAlias := $.Aliases.ManyRelationship $rel.ForeignTable $rel.Name $rel.JoinTable $rel.JoinLocalFKeyName -}}
    
	if {{$relAlias.Local}}Per{{$aliasIn.UpSingular}} * len({{$aliasIn.DownPlural}}) > {{$alias.UpPlural}}ToAdd {
		{{$alias.UpPlural}}ToAdd = {{$relAlias.Local}}Per{{$aliasIn.UpSingular}} * len({{$aliasIn.DownPlural}})
	}

	{{end}}{{/* if */}}


	{{end -}}{{/* range tomany */}}
	{{end -}}{{/* range tables */}}


	for i := 0; i < {{$alias.UpPlural}}ToAdd; i++ {
		// create model
		o, err := Random{{$alias.UpSingular}}()
		if err != nil {
			return fmt.Errorf("unable to get Random{{$alias.UpSingular}}: %w", err)
		}

		{{range $fkey := .Table.FKeys -}}
		{{ $ftable := $.Aliases.Table $fkey.ForeignTable -}}
		{{- $usesPrimitives := usesPrimitives $.Tables $fkey.Table $fkey.Column $fkey.ForeignTable $fkey.ForeignColumn -}}

		// set {{$ftable.DownSingular}}
		{{$ftable.UpSingular}}Key := int(math.Mod(float64(i), float64(len({{$ftable.DownPlural}}))))
		{{$ftable.DownSingular}} := {{$ftable.DownPlural}}[{{$ftable.UpSingular}}Key]

		{{if $usesPrimitives -}}
		o.{{$alias.Column $fkey.Column}} = {{$ftable.DownSingular}}.{{$ftable.Column $fkey.ForeignColumn}}
		{{else -}}
		queries.Assign(&o.{{$alias.Column $fkey.Column}}, {{$ftable.DownSingular}}.{{$ftable.Column $fkey.ForeignColumn}})
		{{end -}}


		{{end}}

		// insert model
		if err := o.Insert({{if not .NoContext}}ctx, {{end}}exec, boil.Infer()); err != nil {
			return fmt.Errorf("unable to insert {{$alias.UpSingular}}: %w", err)
		}

		// run afterAdd
		if err := After{{$alias.UpSingular}}Added(o); err != nil {
			return fmt.Errorf("error running AfterAdd {{$alias.UpSingular}}: %w", err)
		}
	}

	fmt.Println("Finished adding {{$alias.UpPlural}}")
	return nil
}













// These packages are needed in SOME models
// This is to prevent errors in those that do not need it
var _ = math.E
var _ = queries.Query{}

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