# BoilingSeed

This is a CLI tool that helps generate database seeding helpers with [`sqlboiler`](https://github.com/volatiletech/sqlboiler).

This is a really early release, so while it works (I use it for my projects), it is not super stable YET.

## Installation

* Install [`sqlboiler`](https://github.com/volatiletech/sqlboiler)
* Install your database driver for [`sqlboiler`](https://github.com/volatiletech/sqlboiler#supported-databases).
* Generate your models. [Link](https://github.com/volatiletech/sqlboiler#initial-generation)
* Install boilingseed: `go get github.com/stephenafamo/boilingseed`

## Usage

Generate the seeds with:

```shell
boilingseed psql
```

You can then seed the database like this:

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
    seeder := seed.Seeder
    seeder.MinJetsToSeed = 1
    seeder.MinLanguagesToSeed = 1
    seeder.MinPilotsToSeed = 1

    err := seeder.Run(ctx, db)
    if err != nil {
      panic(err)
    }
}
```

## Configuration

By defualt the sqlboiler configuration files are used: `sqlboiler.toml` or `json` or `yaml`.

Apart from the standard configuration for SQLBoiler, the only other added configuration is the package name of the generated SQLBoiler models. By default the models subdirectory of the current go module is used.

The program accepts these flags to overwrite any configuration.

* `--sqlboiler-models`: The package of your generated models. Needed to import them properly in the seeder. DEFAULT: `current/go/module/models`.
* `--config`: Configuration file path. DEFAULT: `sqlboiler.toml`
* `--output` or `-o`: The name of the folder to output to. DEFAULT: `seeds`
* `--pkgname` or `-p`: The name you wish to assign to your generated package. DEFAULT: `seeds`
* `--no-context`: Were the models generated with no context?. DEFAULT `false`
* `--wipe`: Delete the output folder (rm -rf) before generation to ensure sanity. DEFAULT `false`
* `--version`: Print the version
* `debug` or `d`: Debug mode prints stack traces on error. DEFAULT `false`

They can also be set in the config file, or as environment variables

**NOTE:** If you have customized the output folder or pkgname in your `sqlboiler` config file and you are passing the same file to `boilingseed`, you should overwrite them using the `-o` and `p` flags respectively.

## Controlling seeding

Most examples will be demonstrated using the following Postgres schema, structs and variables:

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



The generated package will define a Seeder struct whose fields control seeding.
The comments help understand what each field does.

```go
type Seeder struct {
	// The minimum number of Jets to seed
	MinJetsToSeed int
	// RandomJet creates a random models.Jet
	// It does not need to add relationships.
	// If one is not set, defaultRandomJet() is used
	RandomJet func() (*models.Jet, error)
	// AfterJetsAdded runs after all Jets are added
	AfterJetsAdded func(ctx context.Context) error
	// defaultJetForeignKeySetter() is used if this is not set
	// setting this means that the xxxPerxxx settings cannot be guaranteed
	JetForeignKeySetter func(i int, o *models.Jet, allPilots models.PilotSlice) error

	// The minimum number of Languages to seed
	MinLanguagesToSeed int
	// RandomLanguage creates a random models.Language
	// It does not need to add relationships.
	// If one is not set, defaultRandomLanguage() is used
	RandomLanguage func() (*models.Language, error)
	// AfterLanguagesAdded runs after all Languages are added
	AfterLanguagesAdded func(ctx context.Context) error

	// The minimum number of PilotLanguages to seed
	MinRelsPerPilotLanguages int

	// The minimum number of Pilots to seed
	MinPilotsToSeed int
	// RandomPilot creates a random models.Pilot
	// It does not need to add relationships.
	// If one is not set, defaultRandomPilot() is used
	RandomPilot func() (*models.Pilot, error)
	// AfterPilotsAdded runs after all Pilots are added
	AfterPilotsAdded func(ctx context.Context) error

	JetsPerPilot int

	// Number of times to retry getting a unique relationship in many-to-many relationships
	Retries int
}
```

### `MinXXXToSeed`

The `MinXXXToSeed` variables are used to control how many of each model to seed.

**NOTE:** The final amount seeded could be more than this because of other variables. For example, if **MinJetsToSeed** and **MinPilotsToSeed** are set to `3`, but **JetsPerPilot** is set to `5`, then the final number of Jets seeded will be 15 because each of the 3 pilots need 5 jets.

```go
seeder.MinJetsToSeed = 5
seeder.MinLanguagesToSeed = 4
seeder.MinPilotsToSeed = 3
```

### `xxxPerXXX`

The `xxxPerXXX` fields are used to control how many `one-to-many` relationships are added. For example, if you seed a single pliot, it will auto-seed jets related to that pilot.

```go
seeder.JetsPerPilot = 2
```

### `MinRelsPerXXX`

The `MinRelsPerXXX` fields are control how many `many-to-many` relationships are added. In this example, it will **try** to give each Pilot *at least* 3 Languages and each Language *at least* 3 pilots.

Naturally, if there are more pilots than languages, each language will likely have more than 3 pilots.

```go
seeder.MinRelsPerPilotLanguages = 3
```

### `RandomXXX`

The package has `defaultRandomXXX` functions that use `github.com/volatiletech/randomize`. However, for better control you can set custom `RandomXXX` functions. A single function that randomly generates a model.

The `RandomXXX` functions do not need to add any relationships to the models.

```go
seeder.RandomPilot = func() (*models.Pilot, error) {
    // Build a random pilot
    // Do not worry about relationships those are auto generaeted by the seeder
    // check out github.com/Pallinder/go-randomdata
}

seeder.RandomJet = func() (*models.Jet, error) {
    // Build a random jet
    // Do not worry about relationships those are auto generaeted by the seeder
    // check out github.com/Pallinder/go-randomdata
}

seeder.RandomLanguage = func() (*models.Language, error) {
    // Build a random language
    // Do not worry about relationships those are auto generaeted by the seeder
    // check out github.com/Pallinder/go-randomdata
}
```

### `AfterXXXAdded`

The package has default `AfterXXXAdded` functions that do nothing.

If you'd like to perform any actions after all models of a specific table is added to the database, you can set this field.

```go
seeder.AfterPilotsAdded = func(ctx context.Context) error {
  // Do something
}

seeder.AfterJetsAdded = func(ctx context.Context) error {
  // Do something
}

seeder.AfterLanguagesAdded = func(ctx context.Context) error {
  // Do something
}
```

### `xxxForeignKeySetter`

After a random model is generated, this function is called to set the foreign keys on the model.

In most cases, you wouldn't have to touch this, the default functions evenly distribute relationships to related models.

```go
seeder.	JetForeignKeySetter func(i int, o *models.Jet, allPilots models.PilotSlice) error {
    o.PilotID = 12345
    return nil
}
```

## Testing

BoilingSeed includes comprehensive integration tests that simulate real-world usage scenarios. The integration tests validate the entire workflow from database schema creation to seeder generation and execution.

### Running Integration Tests

To run the complete integration test suite:

```bash
go test -v -run TestBoilingSeedIntegration
```

### What the Integration Tests Cover

The integration tests (`integration_test.go`) include 9 comprehensive test scenarios:

1. **DatabaseSetup** - Creates a temporary SQLite database with a realistic schema (authors, books, categories, book_tags tables)
2. **ProjectStructure** - Sets up a temporary Go project with proper module structure and SQLBoiler configuration
3. **SQLBoilerGeneration** - Generates SQLBoiler models from the database schema
4. **BoilingSeedGeneration** - Runs the boilingseed command to generate seeder files
5. **GeneratedCodeCompilation** - Verifies that all generated code compiles correctly
6. **SeederExecution** - Tests that the generated seeders actually run and create data in the database
7. **CustomSeederFunctions** - Tests custom seeder functions and callbacks (RandomXXX, AfterXXXAdded)
8. **ForeignKeyRelationships** - Verifies that foreign key relationships are properly handled and data integrity is maintained
9. **ConfigurationOptions** - Tests various configuration options (custom output directory, package names, wipe option)

### Test Database Schema

The integration tests use a realistic book store schema with:

```sql
-- Authors table
CREATE TABLE authors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    bio TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Categories table
CREATE TABLE categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Books table with foreign keys
CREATE TABLE books (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    isbn TEXT UNIQUE NOT NULL,
    author_id INTEGER NOT NULL,
    category_id INTEGER NOT NULL,
    published_date DATE,
    pages INTEGER,
    price DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (author_id) REFERENCES authors(id),
    FOREIGN KEY (category_id) REFERENCES categories(id)
);

-- Many-to-many relationship table
CREATE TABLE book_tags (
    book_id INTEGER NOT NULL,
    tag_name TEXT NOT NULL,
    PRIMARY KEY (book_id, tag_name),
    FOREIGN KEY (book_id) REFERENCES books(id)
);
```

### Prerequisites for Running Tests

The integration tests require:

1. **SQLBoiler** - Must be installed and available in your PATH
   ```bash
   go install github.com/volatiletech/sqlboiler/v4@latest
   go install github.com/volatiletech/sqlboiler/v4/drivers/sqlboiler-sqlite3@latest
   ```

2. **Go environment** - The tests create temporary Go modules and build executables

3. **SQLite** - The tests use SQLite as the database backend

### Test Output

The integration tests provide detailed output showing:
- Database setup and schema creation
- SQLBoiler model generation
- BoilingSeed seeder generation
- Code compilation results
- Seeder execution with data counts
- Foreign key relationship validation

Example successful test output:
```
=== RUN   TestBoilingSeedIntegration
=== RUN   TestBoilingSeedIntegration/DatabaseSetup
=== RUN   TestBoilingSeedIntegration/ProjectStructure
=== RUN   TestBoilingSeedIntegration/SQLBoilerGeneration
=== RUN   TestBoilingSeedIntegration/BoilingSeedGeneration
=== RUN   TestBoilingSeedIntegration/GeneratedCodeCompilation
=== RUN   TestBoilingSeedIntegration/SeederExecution
=== RUN   TestBoilingSeedIntegration/CustomSeederFunctions
=== RUN   TestBoilingSeedIntegration/ForeignKeyRelationships
=== RUN   TestBoilingSeedIntegration/ConfigurationOptions
--- PASS: TestBoilingSeedIntegration (9.25s)
```

## Contributing

This still needs some polishing, looking forward to pull requests!
