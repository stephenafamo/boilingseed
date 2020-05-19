# BoilingSeed

This is a CLI tool that helps generate database seeding helpers with [`sqlboiler`](https://github.com/volatiletech/sqlboiler).

This is a really early release, so while it works (I use it for my projects), it is not super stable YET.

## Installation

* Install [`sqlboiler`](https://github.com/volatiletech/sqlboiler)
* Install your database driver for [`sqlboiler`](https://github.com/volatiletech/sqlboiler#supported-databases).
* Generate your models. [Link](https://github.com/volatiletech/sqlboiler#initial-generation)
* Install boilingseed: `go get github.com/stephenafamo/boilingseed`

## Configuration

The config file by default is expected to be at `./sqlboiler.seed.toml`, or pass the flag `-c` or `--config` to the tool when the time comes.

In the configuration, you can duplicate your main sqlboiler config.

**VERY IMPORTANT**: Add the following to your configuration

```toml
[imports.all]
  standard = ['"fmt"', '"bytes"']
  third_party = ['"gitlab.com/stephenafamo/memelify/models"', '"github.com/volatiletech/sqlboiler/v4/boil"', '"github.com/volatiletech/randomize"
```

Next, generate the seeds with:

```shell
boilingseed psql 
```

The program accepts the following flags

* `--config`: Configuration file path. DEFAULT: `sqlboiler.seed.toml`
* `--output` or `-o`: The name of the folder to output to. DEFAULT: `seed`
* `--pkgname` or `-p`: The name you wish to assign to your generated package. DEFAULT: `seed`
* `--no-context`: Disable context.Context usage in the generated code. DEFAULT `false`
* `--wipe`: Delete the output folder (rm -rf) before generation to ensure sanity. DEFAULT `false`

## Usage

Most examples in this section will be demonstrated using the following Postgres schema, structs and variables:

```sql
CREATE TABLE pilots (
  id integer NOT NULL,
  name text NOT NULL
);

ALTER TABLE pilots ADD CONSTRAINT pilot_pkey PRIMARY KEY (id);

CREATE TABLE jets (
  id integer NOT NULL,
  pilot_id integer NOT NULL,
  age integer NOT NULL,
  name text NOT NULL,
  color text NOT NULL
);

ALTER TABLE jets ADD CONSTRAINT jet_pkey PRIMARY KEY (id);
ALTER TABLE jets ADD CONSTRAINT jet_pilots_fkey FOREIGN KEY (pilot_id) REFERENCES pilots(id);

CREATE TABLE languages (
  id integer NOT NULL,
  language text NOT NULL
);

ALTER TABLE languages ADD CONSTRAINT language_pkey PRIMARY KEY (id);

-- Join table
CREATE TABLE pilot_languages (
  pilot_id integer NOT NULL,
  language_id integer NOT NULL
);

-- Composite primary key
ALTER TABLE pilot_languages ADD CONSTRAINT pilot_language_pkey PRIMARY KEY (pilot_id, language_id);
ALTER TABLE pilot_languages ADD CONSTRAINT pilot_language_pilots_fkey FOREIGN KEY (pilot_id) REFERENCES pilots(id);
ALTER TABLE pilot_languages ADD CONSTRAINT pilot_language_languages_fkey FOREIGN KEY (language_id) REFERENCES languages(id);
```

You can seed the entire database like this:

```go
package main

import (
    "context"
    "database/sql"

    "path/to/package/seed"
)

func main() {
    ctx := context.Background()
    db := getDB()
    seed.Pilot(ctx, db)
}
```

## Controlling seeding

The generated package will define the following variables. They can all be overwritten to control seeding:

```go
var JetsPerPilot int = 1
var LanguagesPerPilot int = 1
var PilotsPerLanguage int = 1

var RandomPilot func() *models.Pilot
var RandomJet func() *models.Jet
var RandomLanguage func() *models.Language

var AddJetssToPilot func(ctx context.Context, exec boil.ContextExecutor, o *models.Pilot, amount int) error
var AddLanguagesToPilot func(ctx context.Context, exec boil.ContextExecutor, o *models.Pilot, amount int) error
var AddPilotsToLanguage func(ctx context.Context, exec boil.ContextExecutor, o *models.Language, amount int) error
```

### `xxxPerXXX`

The `xxxPerXXX` variables are used to control how many `to-many` relationships are added. For example, if you seed a single pliot, it will auto-seed jets related to that pilot. By default, that is 1, but you can change it like this:

```go
seed.JetsPerPilot = 3
seed.LanguagesPerPilot = 4
seed.PilotsPerLanguage = 5
```

### `RandomXXX`

The package has default `RandomXXX` functions that use `github.com/volatiletech/randomize`. However, for better control you can set custom `RandomXXX` functions. A single function that randomly generates a model.

The `RandomXXX` functions do not need to add any relationships to the models.

```go
seed.RandomPilot = func()*models.Pilot {
    // Build a random pilot
    // Do not worry about relationships those are auto generaeted by the seeder
    // check out github.com/Pallinder/go-randomdata
}

seed.RandomJet = func()*models.Jet {
    // Build a random jet
    // Do not worry about relationships those are auto generaeted by the seeder
    // check out github.com/Pallinder/go-randomdata
}

seed.RandomLanguage = func()*models.Language {
    // Build a random language
    // Do not worry about relationships those are auto generaeted by the seeder
    // check out github.com/Pallinder/go-randomdata
}
```

### `AddXXXToXXX`

These are only generate for `ToMany` relationships.

The package has default `AddXXXToXXX` functions that work very well, but in custom cases, we may want to control how the relationships are added.

NOTE: The model passed to this function would have already been inserted in the DB. And the function should INSERT the related models too.

```go
seed.AddJetssToPilot = func(ctx context.Context, exec boil.ContextExecutor, o *models.Pilot, amount int) error {
    // Create and insert the related jets
}

seed.AddLanguagesToPilot = func(ctx context.Context, exec boil.ContextExecutor, o *models.Pilot, amount int) error {
    // Create and insert the related languages
}

seed.AddPilotsToLanguage = func(ctx context.Context, exec boil.ContextExecutor, o *models.Language, amount int) error {
    // Create and insert the related pilots
}
```

-----

Once all that is set we can seed our database by calling:

```go
seed.Pilot(ctx, db)
```

Note: Because relationships are auto-seeded, by seeding the pilot, we will seed 3 Jets and 4 languages.

Full code:

```go
package main

import (
    "context"
    "database/sql"

	_ "github.com/lib/pq" // postgres driver

    "github.com/my/module/models"
    "github.com/my/module/seed"
)

func main() {

	db, err := sql.Open("postgres", getDBInfo())
	if err != nil {
		panic(err)
	}

    defer db.Close()

    seed.JetsPerPilot = 3
    seed.LanguagesPerPilot = 4
    seed.PilotsPerLanguage = 5
    
    seed.RandomPilot = func()*models.Pilot {
        // Build a random pilot
    }

    seed.RandomJet = func()*models.Jet {
        // Build a random jet
    }

    seed.RandomLanguage = func()*models.Language {
        // Build a random language
    }

    seed.AddJetssToPilot = func(ctx context.Context, exec boil.ContextExecutor, o *models.Pilot, amount int) error {
        // Create and insert the related jets
    }

    seed.AddLanguagesToPilot = func(ctx context.Context, exec boil.ContextExecutor, o *models.Pilot, amount int) error {
        // Create and insert the related languages
    }

    seed.AddPilotsToLanguage = func(ctx context.Context, exec boil.ContextExecutor, o *models.Language, amount int) error {
        // Create and insert the related pilots
    }


    ctx := context.Background()

    err := seed.Pilot(ctx, db)
    if err != nil {
        panic(err)
    }
}

func getDBInfo() string {
    // Get Postgres DB connection string
}
```

## Contributing

This still needs some polishing, looking forward to pull requests!

Before pushing, run `go generate` so we package the template files in our binary. This is done with [pkger](https://github.com/markbates/pkger).