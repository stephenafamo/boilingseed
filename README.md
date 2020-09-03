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
  standard = ['"fmt"', '"bytes"', '"math"']
  third_party = ['"github.com/stephenafamo/boilingseed/models"', '"github.com/volatiletech/sqlboiler/v4/boil"', '"github.com/volatiletech/sqlboiler/v4/queries"', '"github.com/volatiletech/randomize"']

[imports.singleton."boilingseed_main"]
  standard = ['"fmt"', '"sync"', '"time"', '"context"', '"math/rand"']
  third_party = ['"github.com/stephenafamo/boilingseed/models"', '"github.com/volatiletech/sqlboiler/v4/boil"']
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

-- Join table
CREATE TABLE pilot_languages_2 (
  pilot_id integer NOT NULL,
  language_id integer NOT NULL,
  name text NOT NULL
);

-- Composite primary key
ALTER TABLE pilot_languages_2 ADD CONSTRAINT pilot_language_2_pkey PRIMARY KEY (pilot_id, language_id);
ALTER TABLE pilot_languages_2 ADD CONSTRAINT pilot_language_2_pilots_fkey FOREIGN KEY (pilot_id) REFERENCES pilots(id);
ALTER TABLE pilot_languages_2 ADD CONSTRAINT pilot_language_2_languages_fkey FOREIGN KEY (language_id) REFERENCES languages(id);
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
    seed.Run(ctx, db)
}
```

## Controlling seeding

The generated package will define the following variables. They can all be overwritten to control seeding:

```go

var MinJetsToSeed int = 1
var MinLanguagesToSeed int = 1
var MinPilotsToSeed int = 1

var JetsPerPilot int = 1

var MinRelsPerPilotLanguages = 1

// Number of times to retry getting a unique relationship in many-to-many relationships
var Retries = 3

var RandomPilot func() (*models.Pilot, error)
var RandomJet func() (*models.Jet, error)
var RandomLanguage func() (*models.Language, error)

var AfterPilotAdded func(*models.Pilot) error
var AfterJetAdded func(*models.Pilot) error
var AfterLanguageAdded func(*models.Pilot) error
```

### `MinXXXToSeed`

The `MinXXXToSeed` variables are used to control how many of each model to seed.

**NOTE:** The final amount seeded could be more than this because of other variables. For example, if **MinJetsToSeed** and **MinPilotsToSeed** are set to `3`, but **JetsPerPilot** is set to `5`, then the final number of Jets seeded will be 15 because each of the 3 pilots need 5 jets.

```go
seed.MinJetsToSeed = 5
seed.MinLanguagesToSeed = 4
seed.MinPilotsToSeed = 3
```

### `xxxPerXXX`

The `xxxPerXXX` variables are used to control how many `one-to-many` relationships are added. For example, if you seed a single pliot, it will auto-seed jets related to that pilot. By default, that is 1, but you can change it like this:

```go
seed.JetsPerPilot = 2
```

### `MinRelsPerXXX`

The `MinRelsPerXXX` variables are used to control how many `many-to-many` relationships are added. In this example, it will **try** to give each Pilot *at least* 3 Languages and each Language *at least* 3 pilots.

Naturally, if there are more pilots than languages, each language will likely have more than 3 pilots.

```go
seed.MinRelsPerPilotLanguages = 3
```

### `RandomXXX`

The package has default `RandomXXX` functions that use `github.com/volatiletech/randomize`. However, for better control you can set custom `RandomXXX` functions. A single function that randomly generates a model.

The `RandomXXX` functions do not need to add any relationships to the models.

```go
seed.RandomPilot = func() (*models.Pilot, error) {
    // Build a random pilot
    // Do not worry about relationships those are auto generaeted by the seeder
    // check out github.com/Pallinder/go-randomdata
}

seed.RandomJet = func() (*models.Jet, error) {
    // Build a random jet
    // Do not worry about relationships those are auto generaeted by the seeder
    // check out github.com/Pallinder/go-randomdata
}

seed.RandomLanguage = func() (*models.Language, error) {
    // Build a random language
    // Do not worry about relationships those are auto generaeted by the seeder
    // check out github.com/Pallinder/go-randomdata
}
```

### `AfterXXXAdded`

The package has default `AfterXXXAdded` functions that does nothing.

If you'd like to perform any actions after a model is added to the database, you can overwrite this variable.

For example, you may want to create files for image data added to the database.

```go
seed.AfterPilotAdded = func(*models.Pilot) error {
  // Do something
}

seed.AfterJetAdded = func(*models.Jet) error {
  // Do something
}

seed.AfterLanguageAdded = func(*models.Language) error {
  // Do something
}
```

## Contributing

This still needs some polishing, looking forward to pull requests!

Before pushing, run `go generate` so we package the template files in our binary. This is done with [pkger](https://github.com/markbates/pkger).