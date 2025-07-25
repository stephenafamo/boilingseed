package main

import (
	"database/sql"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	_ "modernc.org/sqlite"
)

const (
	testDBSchema = `
CREATE TABLE authors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    bio TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

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

CREATE TABLE book_tags (
    book_id INTEGER NOT NULL,
    tag_name TEXT NOT NULL,
    PRIMARY KEY (book_id, tag_name),
    FOREIGN KEY (book_id) REFERENCES books(id)
);

CREATE VIEW book_summary AS
SELECT
    b.id,
    b.title,
    a.name as author_name,
    c.name as category_name,
    b.price
FROM books b
JOIN authors a ON b.author_id = a.id
JOIN categories c ON b.category_id = c.id;
`

	sqlBoilerConfig = `
[psql]
  dbname  = "test_db"
  host    = "localhost"
  port    = 5432
  user    = "test"
  pass    = "test"
  sslmode = "disable"

[sqlite3]
  dbname = "%s"

[mysql]
  dbname  = "test_db"
  host    = "localhost"
  port    = 3306
  user    = "test"
  pass    = "test"
`
)

// IntegrationTestSuite holds the state for the integration tests
type IntegrationTestSuite struct {
	tempDir     string
	projectDir  string
	dbPath      string
	modelsDir   string
	seedsDir    string
	binPath     string
	originalDir string
}

func TestBoilingSeedIntegration(t *testing.T) {
	suite := &IntegrationTestSuite{}

	// Setup
	if err := suite.Setup(t); err != nil {
		t.Fatalf("Setup failed: %v", err)
	}
	defer suite.Cleanup(t)

	// Run integration tests
	t.Run("DatabaseSetup", suite.TestDatabaseSetup)
	t.Run("ProjectStructure", suite.TestProjectStructure)
	t.Run("SQLBoilerGeneration", suite.TestSQLBoilerGeneration)
	t.Run("BoilingSeedGeneration", suite.TestBoilingSeedGeneration)
	t.Run("GeneratedCodeCompilation", suite.TestGeneratedCodeCompilation)
	t.Run("SeederExecution", suite.TestSeederExecution)
	t.Run("CustomSeederFunctions", suite.TestCustomSeederFunctions)
	t.Run("ForeignKeyRelationships", suite.TestForeignKeyRelationships)
	t.Run("ConfigurationOptions", suite.TestConfigurationOptions)
}

func (s *IntegrationTestSuite) Setup(t *testing.T) error {
	var err error

	// Remember original directory
	s.originalDir, err = os.Getwd()
	if err != nil {
		return fmt.Errorf("failed to get current directory: %w", err)
	}

	// Create temporary directory
	s.tempDir, err = os.MkdirTemp("", "boilingseed_test_*")
	if err != nil {
		return fmt.Errorf("failed to create temp directory: %w", err)
	}

	// Set up project structure
	s.projectDir = filepath.Join(s.tempDir, "testproject")
	s.dbPath = filepath.Join(s.projectDir, "test.db")
	s.modelsDir = filepath.Join(s.projectDir, "models")
	s.seedsDir = filepath.Join(s.projectDir, "seeds")
	s.binPath = filepath.Join(s.tempDir, "boilingseed")

	// Create project directory
	if err := os.MkdirAll(s.projectDir, 0o755); err != nil {
		return fmt.Errorf("failed to create project directory: %w", err)
	}

	// Build boilingseed binary
	if err := s.buildBoilingSeed(); err != nil {
		return fmt.Errorf("failed to build boilingseed: %w", err)
	}

	// Change to project directory
	if err := os.Chdir(s.projectDir); err != nil {
		return fmt.Errorf("failed to change to project directory: %w", err)
	}

	// Initialize go module
	if err := s.runCommand("go", "mod", "init", "testproject"); err != nil {
		return fmt.Errorf("failed to initialize go module: %w", err)
	}

	// Create database
	if err := s.createDatabase(); err != nil {
		return fmt.Errorf("failed to create database: %w", err)
	}

	return nil
}

func (s *IntegrationTestSuite) Cleanup(t *testing.T) {
	if s.originalDir != "" {
		os.Chdir(s.originalDir)
	}
	if s.tempDir != "" {
		os.RemoveAll(s.tempDir)
	}
}

func (s *IntegrationTestSuite) buildBoilingSeed() error {
	cmd := exec.Command("go", "build", "-o", s.binPath, ".")
	cmd.Dir = s.originalDir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func (s *IntegrationTestSuite) createDatabase() error {
	db, err := sql.Open("sqlite", s.dbPath)
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}
	defer db.Close()

	if _, err := db.Exec(testDBSchema); err != nil {
		return fmt.Errorf("failed to execute schema: %w", err)
	}

	return nil
}

func (s *IntegrationTestSuite) runCommand(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Dir = s.projectDir
	// Add Go bin directory to PATH
	gopath := os.Getenv("GOPATH")
	if gopath == "" {
		gopath = filepath.Join(os.Getenv("HOME"), "go")
	}
	goBin := filepath.Join(gopath, "bin")
	currentPath := os.Getenv("PATH")
	cmd.Env = append(os.Environ(), "PATH="+goBin+":"+currentPath)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func (s *IntegrationTestSuite) runCommandWithOutput(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	cmd.Dir = s.projectDir
	// Add Go bin directory to PATH
	gopath := os.Getenv("GOPATH")
	if gopath == "" {
		gopath = filepath.Join(os.Getenv("HOME"), "go")
	}
	goBin := filepath.Join(gopath, "bin")
	currentPath := os.Getenv("PATH")
	cmd.Env = append(os.Environ(), "PATH="+goBin+":"+currentPath)
	output, err := cmd.CombinedOutput()
	return string(output), err
}

func (s *IntegrationTestSuite) TestDatabaseSetup(t *testing.T) {
	// Verify database exists and has correct schema
	db, err := sql.Open("sqlite", s.dbPath)
	if err != nil {
		t.Fatalf("Failed to open database: %v", err)
	}
	defer db.Close()

	// Test table creation
	tables := []string{"authors", "categories", "books", "book_tags"}
	for _, table := range tables {
		var count int
		query := fmt.Sprintf("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='%s'", table)
		if err := db.QueryRow(query).Scan(&count); err != nil {
			t.Errorf("Failed to check table %s: %v", table, err)
		}
		if count != 1 {
			t.Errorf("Table %s not found", table)
		}
	}

	// Test view creation
	var count int
	if err := db.QueryRow("SELECT COUNT(*) FROM sqlite_master WHERE type='view' AND name='book_summary'").Scan(&count); err != nil {
		t.Errorf("Failed to check view: %v", err)
	}
	if count != 1 {
		t.Errorf("View book_summary not found")
	}
}

func (s *IntegrationTestSuite) TestProjectStructure(t *testing.T) {
	// Create sqlboiler config
	configContent := fmt.Sprintf(sqlBoilerConfig, s.dbPath)
	configPath := filepath.Join(s.projectDir, "sqlboiler.toml")
	if err := os.WriteFile(configPath, []byte(configContent), 0o644); err != nil {
		t.Fatalf("Failed to create config file: %v", err)
	}

	// Verify config file exists
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		t.Error("Config file was not created")
	}

	// Verify database file exists
	if _, err := os.Stat(s.dbPath); os.IsNotExist(err) {
		t.Error("Database file was not created")
	}
}

func (s *IntegrationTestSuite) TestSQLBoilerGeneration(t *testing.T) {
	// Add sqlboiler dependencies
	if err := s.runCommand("go", "get", "github.com/aarondl/sqlboiler/v4"); err != nil {
		t.Fatalf("Failed to get sqlboiler dependency: %v", err)
	}

	if err := s.runCommand("go", "get", "github.com/aarondl/sqlboiler/v4/drivers/sqlboiler-sqlite3"); err != nil {
		t.Fatalf("Failed to get sqlite driver: %v", err)
	}

	// Generate models with sqlboiler
	if err := s.runCommand("sqlboiler", "sqlite3"); err != nil {
		t.Fatalf("Failed to generate models: %v", err)
	}

	// Verify models were generated
	expectedFiles := []string{
		"models/authors.go",
		"models/books.go",
		"models/categories.go",
		"models/book_tags.go",
		"models/boil_queries.go",
		"models/boil_table_names.go",
		"models/boil_types.go",
	}

	for _, file := range expectedFiles {
		path := filepath.Join(s.projectDir, file)
		if _, err := os.Stat(path); os.IsNotExist(err) {
			t.Errorf("Expected model file %s was not generated", file)
		}
	}

	// Verify the models compile
	if err := s.runCommand("go", "mod", "tidy"); err != nil {
		t.Errorf("Failed to tidy modules after model generation: %v", err)
	}

	if err := s.runCommand("go", "build", "./models"); err != nil {
		t.Errorf("Generated models failed to compile: %v", err)
	}
}

func (s *IntegrationTestSuite) TestBoilingSeedGeneration(t *testing.T) {
	// Run boilingseed to generate seeders
	if err := s.runCommand(s.binPath, "sqlite3"); err != nil {
		t.Fatalf("Failed to generate seeders: %v", err)
	}

	// Verify seed files were generated
	expectedFiles := []string{
		"seeds/boilingseed_main.go",
		"seeds/authors.go",
		"seeds/books.go",
		"seeds/categories.go",
		"seeds/book_tags.go",
	}

	for _, file := range expectedFiles {
		path := filepath.Join(s.projectDir, file)
		if _, err := os.Stat(path); os.IsNotExist(err) {
			t.Errorf("Expected seed file %s was not generated", file)
		}
	}

	// Verify that views are not generated as seeds (book_summary should not exist)
	viewSeedPath := filepath.Join(s.projectDir, "seeds/book_summary.go")
	if _, err := os.Stat(viewSeedPath); !os.IsNotExist(err) {
		t.Error("View seed file should not be generated")
	}
}

func (s *IntegrationTestSuite) TestGeneratedCodeCompilation(t *testing.T) {
	// Add required dependencies for seeds
	dependencies := []string{
		"github.com/aarondl/randomize",
		"github.com/lib/pq", // for database drivers in tests
	}

	for _, dep := range dependencies {
		if err := s.runCommand("go", "get", dep); err != nil {
			t.Errorf("Failed to get dependency %s: %v", dep, err)
		}
	}

	if err := s.runCommand("go", "mod", "tidy"); err != nil {
		t.Errorf("Failed to tidy modules: %v", err)
	}

	// Test compilation of seed package
	if err := s.runCommand("go", "build", "./seeds"); err != nil {
		t.Fatalf("Generated seed code failed to compile: %v", err)
	}

	// Create a simple test program to verify the seeder interface
	testProgram := `package main

import (
	"database/sql"
	"fmt"
	"log"

	_ "modernc.org/sqlite"
	"testproject/seeds"
)

func main() {
	db, err := sql.Open("sqlite", "test.db")
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	seeder := seeds.Seeder{
		MinAuthorsToSeed: 1,
		MinCategoriesToSeed: 1,
		MinBooksToSeed: 1,
	}

	fmt.Printf("Seeder initialized with %d min authors\n", seeder.MinAuthorsToSeed)
}
`

	testPath := filepath.Join(s.projectDir, "test_seeder.go")
	if err := os.WriteFile(testPath, []byte(testProgram), 0o644); err != nil {
		t.Fatalf("Failed to create test program: %v", err)
	}

	if err := s.runCommand("go", "build", "test_seeder.go"); err != nil {
		t.Errorf("Test program failed to compile: %v", err)
	}
}

func (s *IntegrationTestSuite) TestSeederExecution(t *testing.T) {
	// Create test program that actually runs the seeder
	testProgram := `package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"math/rand"
	"time"

	_ "modernc.org/sqlite"
	"testproject/seeds"
	"testproject/models"
	"github.com/aarondl/sqlboiler/v4/boil"
)

func main() {
	rand.Seed(time.Now().UnixNano())

	db, err := sql.Open("sqlite", "test.db")
	if err != nil {
		log.Fatal("Failed to open database:", err)
	}
	defer db.Close()

	// Set single connection to avoid database lock issues
	db.SetMaxOpenConns(1)

	// Set debug mode
	boil.DebugMode = true

	// Clear existing data first
	if _, err := db.Exec("DELETE FROM book_tags"); err != nil {
		log.Fatal("Failed to clear book_tags:", err)
	}
	if _, err := db.Exec("DELETE FROM books"); err != nil {
		log.Fatal("Failed to clear books:", err)
	}
	if _, err := db.Exec("DELETE FROM authors"); err != nil {
		log.Fatal("Failed to clear authors:", err)
	}
	if _, err := db.Exec("DELETE FROM categories"); err != nil {
		log.Fatal("Failed to clear categories:", err)
	}

	ctx := context.Background()
	seeder := seeds.Seeder{
		MinAuthorsToSeed: 2,
		MinCategoriesToSeed: 3,
		MinBooksToSeed: 5,
		Retries: 10,
		// Use custom random functions to avoid duplicates
		RandomCategory: func() (*models.Category, error) {
			return &models.Category{
				Name: fmt.Sprintf("Category_%d", rand.Intn(100000)), // Ensure unique names
			}, nil
		},
		RandomAuthor: func() (*models.Author, error) {
			return &models.Author{
				Name:  fmt.Sprintf("Author_%d", rand.Intn(100000)),
				Email: fmt.Sprintf("author_%d@example.com", rand.Intn(100000)),
			}, nil
		},
		RandomBook: func() (*models.Book, error) {
			return &models.Book{
				Title: fmt.Sprintf("Book_%d", rand.Intn(100000)),
				Isbn:  fmt.Sprintf("ISBN-%d", rand.Intn(100000000)), // Ensure unique ISBN
				// Don't set foreign keys here - let the seeder handle them
			}, nil
		},
	}

	fmt.Println("Starting seeder...")
	if err := seeder.Run(ctx, db); err != nil {
		log.Fatal("Seeder failed:", err)
	}
	fmt.Println("Seeding completed successfully!")

	// Verify data was inserted
	authorCount, err := models.Authors().Count(ctx, db)
	if err != nil {
		log.Fatal("Failed to count authors:", err)
	}
	fmt.Printf("Authors created: %d\n", authorCount)

	categoryCount, err := models.Categories().Count(ctx, db)
	if err != nil {
		log.Fatal("Failed to count categories:", err)
	}
	fmt.Printf("Categories created: %d\n", categoryCount)

	bookCount, err := models.Books().Count(ctx, db)
	if err != nil {
		log.Fatal("Failed to count books:", err)
	}
	fmt.Printf("Books created: %d\n", bookCount)

	if authorCount < 2 {
		log.Fatal("Expected at least 2 authors")
	}
	if categoryCount < 3 {
		log.Fatal("Expected at least 3 categories")
	}
	if bookCount < 5 {
		log.Fatal("Expected at least 5 books")
	}
}
`

	testPath := filepath.Join(s.projectDir, "run_seeder.go")
	if err := os.WriteFile(testPath, []byte(testProgram), 0o644); err != nil {
		t.Fatalf("Failed to create seeder test program: %v", err)
	}

	// Get additional dependencies
	if err := s.runCommand("go", "get", "github.com/aarondl/null/v8"); err != nil {
		t.Errorf("Failed to get null dependency: %v", err)
	}

	if err := s.runCommand("go", "mod", "tidy"); err != nil {
		t.Errorf("Failed to tidy modules: %v", err)
	}

	// Build and run the seeder test
	if err := s.runCommand("go", "build", "-o", "run_seeder", "run_seeder.go"); err != nil {
		t.Fatalf("Failed to build seeder test: %v", err)
	}

	output, err := s.runCommandWithOutput("./run_seeder")
	if err != nil {
		t.Fatalf("Failed to run seeder: %v\nOutput: %s", err, output)
	}

	if !strings.Contains(output, "Seeding completed successfully!") {
		t.Error("Seeder did not complete successfully")
	}

	// Verify the output contains expected counts
	expectedStrings := []string{
		"Authors created:",
		"Categories created:",
		"Books created:",
	}

	for _, expected := range expectedStrings {
		if !strings.Contains(output, expected) {
			t.Errorf("Expected output to contain '%s', but it didn't. Output: %s", expected, output)
		}
	}
}

func (s *IntegrationTestSuite) TestCustomSeederFunctions(t *testing.T) {
	// Create test with custom seeder functions
	testProgram := `package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"time"

	_ "modernc.org/sqlite"
	"testproject/seeds"
	"testproject/models"
	"github.com/aarondl/null/v8"
)

func main() {
	db, err := sql.Open("sqlite", "test.db")
	if err != nil {
		log.Fatal("Failed to open database:", err)
	}
	defer db.Close()

	// Set single connection to avoid database lock issues
	db.SetMaxOpenConns(1)

	// Clear existing data
	if _, err := db.Exec("DELETE FROM book_tags"); err != nil {
		log.Fatal("Failed to clear book_tags:", err)
	}
	if _, err := db.Exec("DELETE FROM books"); err != nil {
		log.Fatal("Failed to clear books:", err)
	}
	if _, err := db.Exec("DELETE FROM authors"); err != nil {
		log.Fatal("Failed to clear authors:", err)
	}
	if _, err := db.Exec("DELETE FROM categories"); err != nil {
		log.Fatal("Failed to clear categories:", err)
	}

	ctx := context.Background()
	seeder := seeds.Seeder{
		MinAuthorsToSeed: 1,
		MinCategoriesToSeed: 1,
		MinBooksToSeed: 1,

		// Custom author generator
		RandomAuthor: func() (*models.Author, error) {
			author := &models.Author{
				Name:  "Custom Author",
				Email: fmt.Sprintf("custom%d@example.com", randomInt()),
				Bio:   null.StringFrom("This is a custom author bio"),
			}
			return author, nil
		},

		// After authors added callback
		AfterAuthorsAdded: func(ctx context.Context) error {
			fmt.Println("Custom callback: Authors have been added!")
			return nil
		},
	}

	fmt.Println("Running seeder with custom functions...")
	if err := seeder.Run(ctx, db); err != nil {
		log.Fatal("Seeder failed:", err)
	}

	// Verify custom author was created
	authors, err := models.Authors().All(ctx, db)
	if err != nil {
		log.Fatal("Failed to get authors:", err)
	}

	if len(authors) == 0 {
		log.Fatal("No authors found")
	}

	customAuthorFound := false
	for _, author := range authors {
		if author.Name == "Custom Author" {
			customAuthorFound = true
			fmt.Printf("Found custom author: %s (%s)\n", author.Name, author.Email)
		}
	}

	if !customAuthorFound {
		log.Fatal("Custom author not found")
	}

	fmt.Println("Custom seeder functions test passed!")
}

func randomInt() int {
	return int(time.Now().UnixNano() % 10000)
}
`

	testPath := filepath.Join(s.projectDir, "custom_seeder.go")
	if err := os.WriteFile(testPath, []byte(testProgram), 0o644); err != nil {
		t.Fatalf("Failed to create custom seeder test: %v", err)
	}

	if err := s.runCommand("go", "build", "-o", "custom_seeder", "custom_seeder.go"); err != nil {
		t.Fatalf("Failed to build custom seeder test: %v", err)
	}

	output, err := s.runCommandWithOutput("./custom_seeder")
	if err != nil {
		t.Fatalf("Failed to run custom seeder: %v\nOutput: %s", err, output)
	}

	if !strings.Contains(output, "Custom callback: Authors have been added!") {
		t.Error("Custom callback was not executed")
	}

	if !strings.Contains(output, "Found custom author: Custom Author") {
		t.Error("Custom author function was not used")
	}
}

func (s *IntegrationTestSuite) TestForeignKeyRelationships(t *testing.T) {
	// Test that foreign key relationships are properly handled
	testProgram := `package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"math/rand"
	"time"

	_ "modernc.org/sqlite"
	"testproject/seeds"
	"testproject/models"
	"github.com/aarondl/null/v8"
)

func main() {
	rand.Seed(time.Now().UnixNano())

	db, err := sql.Open("sqlite", "test.db")
	if err != nil {
		log.Fatal("Failed to open database:", err)
	}
	defer db.Close()

	// Set single connection to avoid database lock issues
	db.SetMaxOpenConns(1)

	// Clear existing data
	if _, err := db.Exec("DELETE FROM book_tags"); err != nil {
		log.Fatal("Failed to clear book_tags:", err)
	}
	if _, err := db.Exec("DELETE FROM books"); err != nil {
		log.Fatal("Failed to clear books:", err)
	}
	if _, err := db.Exec("DELETE FROM authors"); err != nil {
		log.Fatal("Failed to clear authors:", err)
	}
	if _, err := db.Exec("DELETE FROM categories"); err != nil {
		log.Fatal("Failed to clear categories:", err)
	}

	ctx := context.Background()
	seeder := seeds.Seeder{
		MinAuthorsToSeed: 3,
		MinCategoriesToSeed: 2,
		MinBooksToSeed: 5,
		// Add custom random functions to prevent UNIQUE constraint violations
		RandomCategory: func() (*models.Category, error) {
			return &models.Category{
				Name: fmt.Sprintf("Category_%d", rand.Intn(100000)),
			}, nil
		},
		RandomAuthor: func() (*models.Author, error) {
			return &models.Author{
				Name:  fmt.Sprintf("Author_%d", rand.Intn(100000)),
				Email: fmt.Sprintf("author_%d@example.com", rand.Intn(100000)),
			}, nil
		},
		RandomBook: func() (*models.Book, error) {
			return &models.Book{
				Title: fmt.Sprintf("Book_%d", rand.Intn(100000)),
				Isbn:  fmt.Sprintf("ISBN-%d", rand.Intn(100000000)),
				// Don't set foreign keys here - let the seeder handle them
			}, nil
		},
	}

	fmt.Println("Testing foreign key relationships...")
	if err := seeder.Run(ctx, db); err != nil {
		log.Fatal("Seeder failed:", err)
	}

	// Verify that all books have valid foreign keys
	books, err := models.Books().All(ctx, db)
	if err != nil {
		log.Fatal("Failed to load books:", err)
	}

	fmt.Printf("Found %d books\n", len(books))

	for _, book := range books {
		fmt.Printf("Book: %s (AuthorID: %d, CategoryID: %d)\n", book.Title, book.AuthorID, book.CategoryID)

		// Check if foreign keys are valid (non-zero)
		if book.AuthorID == 0 {
			log.Fatal("Book has invalid author ID (0)")
		}
		if book.CategoryID == 0 {
			log.Fatal("Book has invalid category ID (0)")
		}

		// Verify the foreign key references exist by manually querying
		author, err := models.FindAuthor(ctx, db, null.Int64From(book.AuthorID))
		if err != nil {
			log.Fatalf("Failed to find author with ID %d: %v", book.AuthorID, err)
		}

		category, err := models.FindCategory(ctx, db, null.Int64From(book.CategoryID))
		if err != nil {
			log.Fatalf("Failed to find category with ID %d: %v", book.CategoryID, err)
		}

		fmt.Printf("Verified relationship: Book '%s' by '%s' in category '%s'\n",
			book.Title, author.Name, category.Name)
	}

	fmt.Println("Foreign key relationships test passed!")

	fmt.Println("Foreign key relationships test passed!")
}
`

	testPath := filepath.Join(s.projectDir, "fk_demo.go")
	if err := os.WriteFile(testPath, []byte(testProgram), 0o644); err != nil {
		t.Fatalf("Failed to create FK test: %v", err)
	}

	output, err := s.runCommandWithOutput("go", "run", "fk_demo.go")
	if err != nil {
		t.Fatalf("Failed to run FK test: %v\nOutput: %s", err, output)
	}

	if !strings.Contains(output, "Foreign key relationships test passed!") {
		t.Error("Foreign key relationships test failed")
	}

	// Should see books with author and category info
	if !strings.Contains(output, "Book:") || !strings.Contains(output, "by") || !strings.Contains(output, "in category") {
		t.Error("Expected to see book relationship information in output")
	}
}

func (s *IntegrationTestSuite) TestConfigurationOptions(t *testing.T) {
	// Test different configuration options
	customOutputDir := filepath.Join(s.projectDir, "custom_seeds")

	// Test custom output directory and package name
	if err := s.runCommand(s.binPath,
		"-o", "custom_seeds",
		"-p", "customseeds",
		"sqlite3"); err != nil {
		t.Fatalf("Failed to generate with custom config: %v", err)
	}

	// Verify custom output directory was created
	if _, err := os.Stat(customOutputDir); os.IsNotExist(err) {
		t.Error("Custom output directory was not created")
	}

	// Verify files were generated in custom directory
	expectedFiles := []string{
		"boilingseed_main.go",
		"authors.go",
		"books.go",
		"categories.go",
	}

	for _, file := range expectedFiles {
		path := filepath.Join(customOutputDir, file)
		if _, err := os.Stat(path); os.IsNotExist(err) {
			t.Errorf("Expected file %s was not generated in custom directory", file)
		}
	}

	// Verify package name was changed
	mainFile := filepath.Join(customOutputDir, "boilingseed_main.go")
	content, err := os.ReadFile(mainFile)
	if err != nil {
		t.Fatalf("Failed to read main file: %v", err)
	}

	if !strings.Contains(string(content), "package customseeds") {
		t.Error("Package name was not changed to customseeds")
	}

	// Test wipe option
	// First create a dummy file in the directory
	dummyFile := filepath.Join(customOutputDir, "dummy.txt")
	if err := os.WriteFile(dummyFile, []byte("dummy"), 0o644); err != nil {
		t.Fatalf("Failed to create dummy file: %v", err)
	}

	// Run with wipe option
	if err := s.runCommand(s.binPath,
		"-o", "custom_seeds",
		"-p", "customseeds",
		"--wipe",
		"sqlite3"); err != nil {
		t.Fatalf("Failed to generate with wipe option: %v", err)
	}

	// Verify dummy file was removed
	if _, err := os.Stat(dummyFile); !os.IsNotExist(err) {
		t.Error("Dummy file was not removed by wipe option")
	}

	// Verify seed files were still generated
	if _, err := os.Stat(mainFile); os.IsNotExist(err) {
		t.Error("Main file was not regenerated after wipe")
	}
}
