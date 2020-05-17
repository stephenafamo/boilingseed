package main

import (
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"text/tabwriter"

	"github.com/markbates/pkger"
	flag "github.com/spf13/pflag"
)

//go:generate go install github.com/markbates/pkger/cmd/pkger
//go:generate pkger

func main() {

	dir, err := ioutil.TempDir("", "boilingseed")
	if err != nil {
		panic(err)
	}
	defer os.RemoveAll(dir)

	// Add a folder for our singleton templates
	if err := os.Mkdir(dir+"/singleton", 0755); err != nil {
		panic(err)
	}

	// Write template files to this directory
	if err := copyTemplates(dir); err != nil {
		panic(err)
	}

	config := flag.StringP("config", "c", "sqlboiler.seed.toml", "Configuration file path")
	output := flag.StringP("output", "o", "seed", "The name of the folder to output to")
	pkgname := flag.StringP("pkgname", "p", "seed", "The name you wish to assign to your generated package")
	noContext := flag.Bool("no-context", false, "Disable context.Context usage in the generated code")
	wipe := flag.Bool("wipe", false, "Delete the output folder (rm -rf) before generation to ensure sanity")
	flag.Parse()

	// cmd := exec.Command("sqlboiler", "-h", os.Args[1])

	args := []string{
		os.Args[1],
		"--templates", dir,
		"--output", *output,
		"--pkgname", *pkgname,
		"--no-tests",
		"--no-driver-templates",
		"--config", *config,
	}

	if *noContext {
		args = append(args, "--no-context")
	}

	if *wipe {
		args = append(args, "--wipe")
	}

	cmd := exec.Command("sqlboiler", args...)

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	// fmt.Println(cmd.String())

	if err := cmd.Run(); err != nil {
		panic(err)
	}
}

func copyTemplates(dir string) error {
	w := tabwriter.NewWriter(os.Stdout, 0, 0, 0, ' ', tabwriter.Debug)
	defer w.Flush()

	return pkger.Walk("/templates", func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return fmt.Errorf("an error was passed to the walkFunc: %w", err)
		}

		if info.IsDir() {
			return nil
		}

		pathArr := strings.Split(path, ":")
		relPath := strings.TrimPrefix(pathArr[len(pathArr)-1], "/templates/")

		tplFile, err := pkger.Open(path)
		if err != nil {
			return fmt.Errorf("error when opening template file: %w", err)
		}
		defer tplFile.Close()

		newFile, err := os.Create(filepath.Join(dir, relPath))
		if err != nil {
			return fmt.Errorf("error when creating new file: %w", err)
		}
		defer newFile.Close()

		_, err = io.Copy(newFile, tplFile)
		if err != nil {
			return fmt.Errorf("error when copying file: %w", err)
		}

		return nil
	})
}
