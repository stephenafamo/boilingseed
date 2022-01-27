{{- if not .Table.IsView -}}
{{ $alias := .Aliases.Table .Table.Name -}}

var (
	{{$alias.DownSingular}}ColumnsWithDefault    = []string{{"{"}}{{.Table.Columns | filterColumnsByDefault true | columnNames | stringMap .StringFuncs.quoteWrap | join ","}}{{"}"}}
	{{$alias.DownSingular}}DBTypes = map[string]string{{"{"}}{{range $i, $col := .Table.Columns -}}{{- if ne $i 0}},{{end}}`{{$alias.Column $col.Name}}`: `{{$col.DBType}}`{{end}}{{"}"}}
)

{{if .Table.FKeys}}
func default{{$alias.UpSingular}}ForeignKeySetter(i int, o *models.{{$alias.UpSingular}}{{- range $fkey := .Table.FKeys -}}{{ $ftable := $.Aliases.Table $fkey.ForeignTable -}}, all{{$ftable.UpPlural}} models.{{$ftable.UpSingular}}Slice{{end}}) error {
		{{range $fkey := .Table.FKeys -}}
		{{ $ftable := $.Aliases.Table $fkey.ForeignTable -}}
		{{- $usesPrimitives := usesPrimitives $.Tables $fkey.Table $fkey.Column $fkey.ForeignTable $fkey.ForeignColumn -}}

		// set {{$ftable.DownSingular}}
		{{$ftable.UpSingular}}Key := int(math.Mod(float64(i), float64(len(all{{$ftable.UpPlural}}))))
		{{$ftable.DownSingular}} := all{{$ftable.UpPlural}}[{{$ftable.UpSingular}}Key]

		{{if $usesPrimitives -}}
		o.{{$alias.Column $fkey.Column}} = {{$ftable.DownSingular}}.{{$ftable.Column $fkey.ForeignColumn}}
		{{else -}}
		queries.Assign(&o.{{$alias.Column $fkey.Column}}, {{$ftable.DownSingular}}.{{$ftable.Column $fkey.ForeignColumn}})
		{{end}}
    {{end -}}

    return nil
}
{{end}}

// defaultRandom{{$alias.UpSingular}} creates a random model.{{$alias.UpSingular}}
// Used when Random{{$alias.UpSingular}} is not set in the Seeder
func defaultRandom{{$alias.UpSingular}}() (*models.{{$alias.UpSingular}}, error){
	o := &models.{{$alias.UpSingular}}{}
	seed := randomize.NewSeed()
	err := randomize.Struct(seed, o, {{$alias.DownSingular}}DBTypes, true, {{$alias.DownSingular}}ColumnsWithDefault...)

	return o, err
}

func (s Seeder) seed{{$alias.UpPlural}}(ctx context.Context, exec boil.ContextExecutor) error {
	fmt.Println("Adding {{$alias.UpPlural}}")
	{{$alias.UpPlural}}ToAdd := s.Min{{$alias.UpPlural}}ToSeed

  randomFunc := s.Random{{$alias.UpSingular}}
  if randomFunc == nil {
      randomFunc = defaultRandom{{$alias.UpSingular}}
  }

  {{if .Table.FKeys}}
  fkFunc := s.{{$alias.UpSingular}}ForeignKeySetter
  if fkFunc == nil {
      fkFunc = default{{$alias.UpSingular}}ForeignKeySetter
  }
  {{end}}

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
    
	if s.{{$relAlias.Local}}Per{{$aliasIn.UpSingular}} * len({{$aliasIn.DownPlural}}) > {{$alias.UpPlural}}ToAdd {
		{{$alias.UpPlural}}ToAdd = s.{{$relAlias.Local}}Per{{$aliasIn.UpSingular}} * len({{$aliasIn.DownPlural}})
	}

	{{end}}{{/* if */}}


	{{end -}}{{/* range tomany */}}
	{{end -}}{{/* range tables */}}


	for i := 0; i < {{$alias.UpPlural}}ToAdd; i++ {
		// create model
		o, err := randomFunc()
		if err != nil {
			return fmt.Errorf("unable to get Random {{$alias.UpSingular}}: %w", err)
		}

    {{if .Table.FKeys}}
    // Set foreign keys
    err = fkFunc(i, o{{- range $fkey := $.Table.FKeys -}}{{ $ftable := $.Aliases.Table $fkey.ForeignTable -}}, {{$ftable.DownPlural}}{{end}})
		if err != nil {
			return fmt.Errorf("unable to get set foreign keys for {{$alias.UpSingular}}: %w", err)
		}
    {{end}}{{/* if */}}

		// insert model
		if err := o.Insert({{if not .NoContext}}ctx, {{end}}exec, boil.Infer()); err != nil {
			return fmt.Errorf("unable to insert {{$alias.UpSingular}}: %w", err)
		}
	}

    // run afterAdd
    if s.After{{$alias.UpPlural}}Added != nil {
      if err := s.After{{$alias.UpPlural}}Added(ctx); err != nil {
          return fmt.Errorf("error running After{{$alias.UpPlural}}Added: %w", err)
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
	{{- $alias.Column $column.Name}} {{$column.Type}}
	{{end -}}
}
{{- end -}}
