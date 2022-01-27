type Seeder struct {
    {{range $table := .Tables}}{{ $alias := $.Aliases.Table $table.Name -}}
    {{- if $table.IsJoinTable }}
        // The minimum number of {{titleCase $table.Name}} to seed
        MinRelsPer{{titleCase $table.Name}} int
    {{ else if not $table.IsView -}}
        // The minimum number of {{$alias.UpPlural}} to seed
        Min{{$alias.UpPlural}}ToSeed int
        // Random{{$alias.UpSingular}} creates a random models.{{$alias.UpSingular}}
        // It does not need to add relationships.
        // If one is not set, defaultRandom{{$alias.UpSingular}}() is used
        Random{{$alias.UpSingular}} func() (*models.{{$alias.UpSingular}}, error)
        // After{{$alias.UpPlural}}Added runs after all {{$alias.UpPlural}} are added
        After{{$alias.UpPlural}}Added func(ctx context.Context) error
        {{if $table.FKeys -}}
        // default{{$alias.UpSingular}}ForeignKeySetter() is used if this is not set
        // setting this means that the xxxPerxxx settings cannot be guaranteed
        {{$alias.UpSingular}}ForeignKeySetter func(i int, o *models.{{$alias.UpSingular}}{{- range $fkey := $table.FKeys -}}{{ $ftable := $.Aliases.Table $fkey.ForeignTable -}}, all{{$ftable.UpPlural}} models.{{$ftable.UpSingular}}Slice{{end}}) error
        {{end}}
    {{- end}}

    {{end}}{{/* range tables */}}

    {{range $table := .Tables -}}{{ $alias := $.Aliases.Table $table.Name -}}
    {{range $table.ToManyRelationships -}}{{if not .ToJoinTable -}}
        {{- $ftable := $.Aliases.Table .ForeignTable -}}
        {{- $relAlias := $.Aliases.ManyRelationship .ForeignTable .Name .JoinTable .JoinLocalFKeyName -}}
        {{$relAlias.Local}}Per{{$alias.UpSingular}} int
    {{end -}}{{/* if jointable */}}
    {{- end -}}{{/* range tomany */}}
    {{- end -}}{{/* range tables */}}

    // Number of times to retry getting a unique relationship in many-to-many relationships
    Retries int
}


func (s Seeder) Run(ctx context.Context, exec boil.ContextExecutor) error {
	rand.Seed(time.Now().Unix())
	var wg sync.WaitGroup

	ctxMain, cancelMain := context.WithCancel(ctx)
	defer cancelMain()
	
	{{range $table := .Tables}}{{if $table.IsJoinTable -}}
	ctx{{titleCase $table.Name}}, cancel{{titleCase $table.Name}} := context.WithCancel(ctxMain)
	{{else if not $table.IsView -}}
	{{ $alias := $.Aliases.Table $table.Name -}}
	ctx{{$alias.UpPlural}}, cancel{{$alias.UpPlural}} := context.WithCancel(ctxMain)
	{{end}}{{end -}}{{/* range tables */}}

    errChan := make(chan error, {{len .Tables}})

	{{range $table := .Tables }}{{if not $table.IsView -}}
	{{ $alias := $.Aliases.Table $table.Name }}
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
		if err := s.seed{{$alias.UpPlural}}(ctx{{$alias.UpPlural}}, exec); err != nil {
			errChan <- err
			cancelMain()
		}
		{{else}}
		if err := s.seed{{titleCase $table.Name}}(ctx{{titleCase $table.Name}}, exec); err != nil {
			errChan <- err
			cancelMain()
		}
		{{- end -}}
	}()
	{{end}}{{/* range not IsView */}}
	{{end}}{{/* range tables */}}

	wg.Wait()

	close(errChan)
	err := <-errChan
	if err != nil {
		return err
	}

	return nil
}

{{range $table := .Tables}}{{if $table.IsJoinTable -}}
{{/* A Join table will have exactly 2 foreign keys */}}
{{ $fkey0 := (index $table.FKeys 0) }}
{{ $fkey1 := (index $table.FKeys 1) }}
{{ $alias := $.Aliases.Table $table.Name -}}
{{ $alias0 := $.Aliases.Table $fkey0.ForeignTable -}}
{{ $alias1 := $.Aliases.Table $fkey1.ForeignTable -}}
{{ $relAlias0 := $alias.Relationship $fkey0.Name -}}
{{ $relAlias1 := $alias.Relationship $fkey1.Name -}}
func (s Seeder) seed{{titleCase $table.Name}}(ctx context.Context, exec boil.ContextExecutor) error {
	fmt.Println("Adding {{titleCase $table.Name}}")
	NoOfRels := s.MinRelsPer{{titleCase $table.Name}}

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
				
				for alreadyIn && retries < s.Retries {
					retries++
					index = rand.Int() % len({{$alias1.DownPlural}})
					 _, alreadyIn = relatedIndexes[index]
				}

        if !alreadyIn {
            relatedIndexes[index] = struct{}{}
            related = append(related, {{$alias1.DownPlural}}[index])
        }
			}

			o.Add{{$relAlias0.Local}}({{if not $.NoContext}}ctx, {{end}}exec, false, related...)
		}

	case  len({{$alias1.DownPlural}}) <= len({{$alias0.DownPlural}}):
		for i := 0; i < len({{$alias1.DownPlural}}); i++ {
			o := {{$alias1.DownPlural}}[i]

			relatedIndexes := map[int]struct{}{}
			related := models.{{$alias0.UpSingular}}Slice{}

			for i := 0; i < NoOfRels; i++ {
				index := rand.Int() % len({{$alias0.DownPlural}})
				_, alreadyIn := relatedIndexes[index]
				retries := 0
				
				for alreadyIn && retries < s.Retries {
					retries++
					index = rand.Int() % len({{$alias0.DownPlural}})
					 _, alreadyIn = relatedIndexes[index]
				}

        if !alreadyIn {
            relatedIndexes[index] = struct{}{}
            related = append(related, {{$alias0.DownPlural}}[index])
        }
			}

			o.Add{{$relAlias1.Local}}({{if not $.NoContext}}ctx, {{end}}exec, false, related...)
		}
	}

	return nil
}
{{end}}{{end -}}{{/* range tables */}}




// These packages are needed in SOME models
// This is to prevent errors in those that do not need it
var _ fmt.Scanner
var _ = models.NewQuery()
