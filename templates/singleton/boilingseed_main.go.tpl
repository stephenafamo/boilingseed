{{range $table := .Tables}}{{if not $table.IsJoinTable -}}
{{ $alias := $.Aliases.Table $table.Name -}}
var Min{{$alias.UpPlural}}ToSeed int = 1
{{end}}{{end -}}{{/* range tables */}}

{{range $table := .Tables -}}
{{ $alias := $.Aliases.Table $table.Name -}}
{{range $table.ToManyRelationships -}}
{{if not .ToJoinTable -}}
{{- $ftable := $.Aliases.Table .ForeignTable -}}
{{- $relAlias := $.Aliases.ManyRelationship .ForeignTable .Name .JoinTable .JoinLocalFKeyName -}}
var {{$relAlias.Local}}Per{{$alias.UpSingular}} int = 1
{{end -}}{{/* if jointable */}}
{{- end -}}{{/* range tomany */}}
{{- end -}}{{/* range tables */}}

{{range $table := .Tables}}{{if $table.IsJoinTable -}}
var MinRelsPer{{titleCase $table.Name}} = 1
{{end -}}{{end -}}

// Number of times to retry getting a unique relationship in many-to-many relationships
var Retries = 3


func init() {
	rand.Seed(time.Now().Unix())
}

func Run(ctx context.Context, exec boil.ContextExecutor) {
	var wg sync.WaitGroup

	ctxMain, cancelMain := context.WithCancel(ctx)
	defer cancelMain()
	
	{{range $table := .Tables}}{{if not $table.IsJoinTable -}}
	{{ $alias := $.Aliases.Table $table.Name -}}
	ctx{{$alias.UpPlural}}, cancel{{$alias.UpPlural}} := context.WithCancel(ctxMain)
	{{else -}}
	ctx{{titleCase $table.Name}}, cancel{{titleCase $table.Name}} := context.WithCancel(ctxMain)
	{{end}}{{end -}}{{/* range tables */}}



	{{range $table := .Tables -}}
	{{ $alias := $.Aliases.Table $table.Name -}}
	// Run{{$alias.UpPlural}}Seed()
	wg.Add(1)
	go func() {
		defer cancel{{if not $table.IsJoinTable -}}{{$alias.UpPlural}}{{else}}{{titleCase $table.Name}}{{end}}()
		defer wg.Done()
		{{range $table.FKeys -}}
		{{ $ftable := $.Aliases.Table .ForeignTable -}}
		<-ctx{{$ftable.UpPlural}}.Done()
		{{end}}
		{{if not $table.IsJoinTable -}}
		if err := seed{{$alias.UpPlural}}(ctx{{$alias.UpPlural}}, exec); err != nil {
			panic(err)
		}
		{{else}}
		if err := seed{{titleCase $table.Name}}(ctx{{titleCase $table.Name}}, exec); err != nil {
			panic(err)
		}
		{{- end}}
	}()
	{{end}}{{/* range tables */}}

	wg.Wait()
}

{{range $table := .Tables}}{{if $table.IsJoinTable -}}
{{/* A Join table will have exactly 2 foreign keys */}}
{{ $alias0 := $.Aliases.Table (index $table.FKeys 0).ForeignTable -}}
{{ $alias1 := $.Aliases.Table (index $table.FKeys 1).ForeignTable -}}
func seed{{titleCase $table.Name}}(ctx context.Context, exec boil.ContextExecutor) error {
	fmt.Println("Adding {{titleCase $table.Name}}")
	NoOfRels := MinRelsPer{{titleCase $table.Name}}

	{{range $table.FKeys -}}
	{{ $ftable := $.Aliases.Table .ForeignTable -}}
	{{$ftable.DownPlural}}, err := models.{{$ftable.UpPlural}}().All({{if not $.NoContext}}ctx, {{end}}exec)
	if err != nil {
		return fmt.Errorf("error getting {{$ftable.DownPlural}}: %w", err)
	}

	if NoOfRels < len({{$ftable.DownPlural}}) {
		NoOfRels = len({{$ftable.DownPlural}})
	}

	{{end}}

    // Seed from the lesser one
	switch {
	case len({{$alias0.DownPlural}}) <  len({{$alias1.DownPlural}}):
		for i := 0; i < len({{$alias0.DownPlural}}); i++ {
			o := {{$alias0.DownPlural}}[i]

			relatedIndexes := map[int]struct{}{}
			related := models.{{$alias1.UpSingular}}Slice{}

			for i := 0; i < NoOfRels; i++ {
				index := rand.Int() % len({{$alias1.DownPlural}})
				_, alreadyIn := relatedIndexes[index]
				retries := 0
				
				for alreadyIn && retries < Retries {
					retries++
					index = rand.Int() % len({{$alias1.DownPlural}})
					 _, alreadyIn = relatedIndexes[index]
				}
				relatedIndexes[index] = struct{}{}
				related = append(related, {{$alias1.DownPlural}}[index])
			}

			o.Add{{$alias1.UpPlural}}({{if not $.NoContext}}ctx, {{end}}exec, false, related...)
		}
	case  len({{$alias1.DownPlural}}) <= len({{$alias0.DownPlural}}):
		for i := 0; i < len({{$alias1.DownPlural}}); i++ {
		}
	}

	



	return nil
}
{{end}}{{end -}}{{/* range tables */}}


// These packages are needed in SOME models
// This is to prevent errors in those that do not need it
var _ fmt.Scanner
var _ = models.NewQuery()